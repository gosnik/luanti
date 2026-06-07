// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#ifndef __SWITCH__
#error This file may only be compiled for Nintendo Switch!
#endif

#include "porting.h"

#include "filesys.h"
#include "log.h"

#include <switch.h>

#include <cstdlib>
#include <cstdio>
#include <deque>
#include <iomanip>
#include <mutex>
#include <sstream>
#include <vector>

namespace porting
{

static bool g_socket_initialized = false;
static bool g_applet_exit_locked = false;
static bool g_romfs_initialized = false;
static AppletHookCookie g_applet_hook_cookie = {};
static bool g_applet_hooked = false;
static AppletFocusState g_focus_state = AppletFocusState_InFocus;
static bool g_was_backgrounded = false;
static std::mutex g_debug_overlay_mutex;
static std::deque<std::string> g_debug_overlay_lines;
static constexpr const char *SWITCH_APP_DIR = "sdmc:/switch/luanti";
static constexpr const char *SWITCH_BOOT_LOG = "sdmc:/switch/luanti/switch_boot.txt";
static constexpr const char *SWITCH_FORWARDER_DIR = "sdmc:/switch/luanti/forwarder";
static constexpr const char *SWITCH_FORWARDER_MANIFEST =
	"sdmc:/switch/luanti/forwarder/luanti-forwarder.txt";
static constexpr const char *SWITCH_FORWARDER_README =
	"sdmc:/switch/luanti/forwarder/README.txt";
static constexpr const char *SWITCH_FORWARDER_NRO_PATH =
	"sdmc:/switch/luanti/luanti.nro";
static constexpr const char *SWITCH_FORWARDER_ICON_PATH =
	"sdmc:/switch/luanti/icon.jpg";
static constexpr u64 SWITCH_FORWARDER_TITLE_ID = 0x0157c4e2607bb000ULL;

void switchDebugTrace(const char *message)
{
	const char *safe_message = message ? message : "";
	{
		std::lock_guard<std::mutex> lock(g_debug_overlay_mutex);
		g_debug_overlay_lines.emplace_back(safe_message);
		while (g_debug_overlay_lines.size() > 8)
			g_debug_overlay_lines.pop_front();
	}

	if (g_focus_state != AppletFocusState_Background) {
		std::printf("[luanti-switch] %s\n", safe_message);
		std::fflush(stdout);
	}

	FILE *file = std::fopen(SWITCH_BOOT_LOG, "a");
	if (!file)
		return;
	std::fprintf(file, "%s\n", safe_message);
	std::fclose(file);
}

std::string switchGetDebugTraceOverlay()
{
	std::ostringstream os;
	std::lock_guard<std::mutex> lock(g_debug_overlay_mutex);
	for (const std::string &line : g_debug_overlay_lines)
		os << "\n" << line;
	return os.str();
}

static const char *focusStateName(AppletFocusState state)
{
	switch (state) {
	case AppletFocusState_InFocus:
		return "InFocus";
	case AppletFocusState_OutOfFocus:
		return "OutOfFocus";
	case AppletFocusState_Background:
		return "Background";
	default:
		return "Unknown";
	}
}

static void updateFocusState(const char *reason)
{
	AppletFocusState new_state = appletGetFocusState();
	if (new_state == g_focus_state)
		return;

	g_focus_state = new_state;
	if (g_focus_state == AppletFocusState_Background)
		g_was_backgrounded = true;
	char buffer[128];
	std::snprintf(buffer, sizeof(buffer),
		"applet focus: %s via %s", focusStateName(g_focus_state), reason);
	switchDebugTrace(buffer);
}

static void appletStatusHook(AppletHookType hook, void *param)
{
	(void)param;

	if (hook == AppletHookType_OnFocusState) {
		updateFocusState("focus hook");
	} else if (hook == AppletHookType_OnResume) {
		updateFocusState("resume hook");
		switchDebugTrace("applet resume");
	} else if (hook == AppletHookType_OnExitRequest) {
		switchDebugTrace("applet exit requested");
	}
}

bool switchProcessAppEvents()
{
	if (!appletMainLoop()) {
		switchDebugTrace("appletMainLoop requested exit");
		return false;
	}

	updateFocusState("main loop");
	return true;
}

bool switchIsForeground()
{
	return g_focus_state != AppletFocusState_Background;
}

bool switchConsumeBackgrounded()
{
	const bool was_backgrounded = g_was_backgrounded;
	g_was_backgrounded = false;
	if (was_backgrounded)
		switchDebugTrace("applet background state consumed");
	return was_backgrounded;
}

static bool switchHasForwarderLauncher()
{
	Result rc = nsInitialize();
	if (R_FAILED(rc)) {
		char buffer[96];
		std::snprintf(buffer, sizeof(buffer),
			"forwarder: nsInitialize failed 0x%x",
			static_cast<unsigned int>(rc));
		switchDebugTrace(buffer);
		return false;
	}

	bool found = false;
	s32 offset = 0;
	while (!found) {
		NsApplicationRecord records[64] = {};
		s32 count = 0;
		rc = nsListApplicationRecord(records, 64, offset, &count);
		if (R_FAILED(rc)) {
			char buffer[128];
			std::snprintf(buffer, sizeof(buffer),
				"forwarder: nsListApplicationRecord failed 0x%x",
				static_cast<unsigned int>(rc));
			switchDebugTrace(buffer);
			break;
		}

		if (count <= 0)
			break;

		for (s32 i = 0; i < count; i++) {
			if (records[i].application_id == SWITCH_FORWARDER_TITLE_ID) {
				found = true;
				break;
			}
		}
		offset += count;
	}

	nsExit();

	char buffer[128];
	std::snprintf(buffer, sizeof(buffer),
		"forwarder: title 0x%016llx %s",
		static_cast<unsigned long long>(SWITCH_FORWARDER_TITLE_ID),
		found ? "installed" : "missing");
	switchDebugTrace(buffer);
	return found;
}

static void switchWriteForwarderRequest()
{
	bool ok = fs::CreateAllDirs(SWITCH_FORWARDER_DIR);
	switchDebugTrace(ok ?
		"forwarder: metadata dir ok" : "forwarder: metadata dir failed");
	if (!ok)
		return;

	FILE *manifest = std::fopen(SWITCH_FORWARDER_MANIFEST, "w");
	if (!manifest) {
		switchDebugTrace("forwarder: failed to write manifest");
		return;
	}

	std::fprintf(manifest, "name=Luanti\n");
	std::fprintf(manifest, "publisher=Luanti\n");
	std::fprintf(manifest, "version=0.1\n");
	std::fprintf(manifest, "title_id=0x%016llx\n",
		static_cast<unsigned long long>(SWITCH_FORWARDER_TITLE_ID));
	std::fprintf(manifest, "nro=%s\n", SWITCH_FORWARDER_NRO_PATH);
	std::fprintf(manifest, "icon=%s\n", SWITCH_FORWARDER_ICON_PATH);
	std::fclose(manifest);

	FILE *readme = std::fopen(SWITCH_FORWARDER_README, "w");
	if (readme) {
		std::fprintf(readme,
			"Luanti did not find its Home Menu forwarder.\n"
			"Use nsp-forwarder with these values to generate/install it:\n"
			"name: Luanti\n"
			"publisher: Luanti\n"
			"version: 0.1\n"
			"title_id: 0x%016llx\n"
			"nro: %s\n"
			"icon: %s\n",
			static_cast<unsigned long long>(SWITCH_FORWARDER_TITLE_ID),
			SWITCH_FORWARDER_NRO_PATH,
			SWITCH_FORWARDER_ICON_PATH);
		std::fclose(readme);
	}

	switchDebugTrace("forwarder: wrote on-device metadata");
}

static void switchEnsureForwarderLauncher()
{
	if (switchHasForwarderLauncher())
		return;

	switchDebugTrace("forwarder: launcher missing; wrote metadata only");
	switchWriteForwarderRequest();
}

bool switchShowTextInputDialog(const std::string &current, int edit_type,
		std::string *out_text)
{
	if (!out_text)
		return false;

	switchDebugTrace("switchShowTextInputDialog: begin");

	SwkbdConfig config;
	Result rc = swkbdCreate(&config, 0);
	if (R_FAILED(rc)) {
		char buffer[96];
		std::snprintf(buffer, sizeof(buffer),
			"switchShowTextInputDialog: swkbdCreate failed 0x%x",
			static_cast<unsigned int>(rc));
		switchDebugTrace(buffer);
		return false;
	}

	if (edit_type == 3) {
		swkbdConfigMakePresetPassword(&config);
	} else {
		swkbdConfigMakePresetDefault(&config);
		if (edit_type == 1)
			swkbdConfigSetReturnButtonFlag(&config, 0);
	}

	swkbdConfigSetInitialText(&config, current.c_str());
	swkbdConfigSetStringLenMax(&config, 1024);
	swkbdConfigSetOkButtonText(&config, "OK");

	std::vector<char> output(1025, '\0');
	rc = swkbdShow(&config, output.data(), output.size());
	swkbdClose(&config);

	updateFocusState("software keyboard");

	if (R_FAILED(rc)) {
		char buffer[96];
		std::snprintf(buffer, sizeof(buffer),
			"switchShowTextInputDialog: swkbdShow canceled/failed 0x%x",
			static_cast<unsigned int>(rc));
		switchDebugTrace(buffer);
		return false;
	}

	*out_text = output.data();
	while (!out_text->empty() &&
			(out_text->back() == '\n' || out_text->back() == '\r')) {
		out_text->pop_back();
	}
	switchDebugTrace("switchShowTextInputDialog: accepted");
	return true;
}

static void cleanupSwitch()
{
	switchDebugTrace("cleanupSwitch: begin");
	if (g_applet_hooked) {
		appletUnhook(&g_applet_hook_cookie);
		g_applet_hooked = false;
		switchDebugTrace("cleanupSwitch: applet hook removed");
	}

	if (g_applet_exit_locked) {
		appletUnlockExit();
		g_applet_exit_locked = false;
		switchDebugTrace("cleanupSwitch: applet exit unlocked");
	}

	if (g_socket_initialized) {
		socketExit();
		g_socket_initialized = false;
		switchDebugTrace("cleanupSwitch: socket exited");
	}

	if (g_romfs_initialized) {
		romfsExit();
		g_romfs_initialized = false;
		switchDebugTrace("cleanupSwitch: romfs exited");
	}
	switchDebugTrace("cleanupSwitch: end");
}

void osSpecificInit()
{
	fs::CreateAllDirs(SWITCH_APP_DIR);
	std::remove(SWITCH_BOOT_LOG);
	switchDebugTrace("osSpecificInit: begin");

	Result rc = socketInitializeDefault();
	if (R_SUCCEEDED(rc)) {
		g_socket_initialized = true;
		switchDebugTrace("osSpecificInit: socketInitializeDefault ok");
	} else {
		warningstream << "socketInitializeDefault failed: 0x"
			<< std::hex << rc << std::dec << std::endl;
		char buffer[96];
		std::snprintf(buffer, sizeof(buffer),
			"osSpecificInit: socketInitializeDefault failed 0x%x",
			static_cast<unsigned int>(rc));
		switchDebugTrace(buffer);
	}

	rc = romfsInit();
	if (R_SUCCEEDED(rc)) {
		g_romfs_initialized = true;
		switchDebugTrace("osSpecificInit: romfsInit ok");
	} else {
		char buffer[64];
		std::snprintf(buffer, sizeof(buffer),
			"osSpecificInit: romfsInit failed 0x%x",
			static_cast<unsigned int>(rc));
		switchDebugTrace(buffer);
	}

	appletLockExit();
	g_applet_exit_locked = true;
	switchDebugTrace("osSpecificInit: applet exit locked");

	rc = appletSetFocusHandlingMode(AppletFocusHandlingMode_SuspendHomeSleepNotify);
	if (R_SUCCEEDED(rc)) {
		switchDebugTrace("osSpecificInit: focus handling notify ok");
	} else {
		char buffer[96];
		std::snprintf(buffer, sizeof(buffer),
			"osSpecificInit: focus handling notify failed 0x%x",
			static_cast<unsigned int>(rc));
		switchDebugTrace(buffer);
	}

	g_focus_state = appletGetFocusState();
	appletHook(&g_applet_hook_cookie, appletStatusHook, nullptr);
	g_applet_hooked = true;
	switchDebugTrace("osSpecificInit: applet hook installed");

	std::atexit(cleanupSwitch);

	unsetenv("LANGUAGE");
	setenv("LANG", "en_US.UTF-8", 1);
	switchDebugTrace("osSpecificInit: end");
}

bool setSystemPaths()
{
	switchDebugTrace("setSystemPaths: begin");
	path_share = g_romfs_initialized ? "romfs:" : SWITCH_APP_DIR;
	path_user = SWITCH_APP_DIR;
	path_cache = path_user + DIR_DELIM "cache";

	bool ok = true;
	ok = fs::CreateAllDirs(path_user) && ok;
	switchDebugTrace(ok ? "setSystemPaths: user dir ok" : "setSystemPaths: user dir failed");
	switchDebugTrace(g_romfs_initialized ?
		"setSystemPaths: share path romfs" : "setSystemPaths: share path sdmc");
	ok = fs::CreateAllDirs(path_cache) && ok;
	switchDebugTrace(ok ? "setSystemPaths: cache dir ok" : "setSystemPaths: cache dir failed");
	ok = fs::CreateAllDirs(path_cache + DIR_DELIM "media") && ok;
	switchDebugTrace(ok ? "setSystemPaths: media cache dir ok" : "setSystemPaths: media cache dir failed");
	ok = fs::CreateAllDirs(path_user + DIR_DELIM "worlds") && ok;
	switchDebugTrace(ok ? "setSystemPaths: worlds dir ok" : "setSystemPaths: worlds dir failed");
	ok = fs::CreateAllDirs(path_user + DIR_DELIM "screenshots") && ok;
	switchDebugTrace(ok ? "setSystemPaths: screenshots dir ok" : "setSystemPaths: screenshots dir failed");
	ok = fs::CreateAllDirs(path_user + DIR_DELIM "client") && ok;
	switchDebugTrace(ok ? "setSystemPaths: client dir ok" : "setSystemPaths: client dir failed");
	switchEnsureForwarderLauncher();

	switchDebugTrace(ok ? "setSystemPaths: end ok" : "setSystemPaths: end failed");
	return ok;
}

} // namespace porting
