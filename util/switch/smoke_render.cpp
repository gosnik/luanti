// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later

#include <SDL.h>
#include <GLES2/gl2.h>
#include <switch.h>

#include <cstdio>

namespace
{

constexpr int MAX_CONTROLLERS = 8;

void delay_frames(int frames)
{
	for (int i = 0; i < frames; i++) {
		appletMainLoop();
		SDL_Delay(16);
	}
}

void log_sdl_error(const char *message)
{
	std::printf("%s: %s\n", message, SDL_GetError());
	std::fflush(stdout);
}

void open_controllers(SDL_GameController *controllers[MAX_CONTROLLERS])
{
	const int joystick_count = SDL_NumJoysticks();
	std::printf("SDL joysticks: %d\n", joystick_count);
	for (int i = 0; i < joystick_count && i < MAX_CONTROLLERS; i++) {
		const char *name = SDL_JoystickNameForIndex(i);
		const SDL_bool is_controller = SDL_IsGameController(i);
		std::printf("  [%d] %s controller=%s\n", i, name ? name : "(unknown)",
				is_controller ? "yes" : "no");
		if (is_controller) {
			controllers[i] = SDL_GameControllerOpen(i);
			if (!controllers[i])
				log_sdl_error("SDL_GameControllerOpen failed");
		}
	}
	std::fflush(stdout);
}

void close_controllers(SDL_GameController *controllers[MAX_CONTROLLERS])
{
	for (int i = 0; i < MAX_CONTROLLERS; i++) {
		if (controllers[i])
			SDL_GameControllerClose(controllers[i]);
	}
}

void log_controller_event(const SDL_Event &event)
{
	switch (event.type) {
	case SDL_CONTROLLERDEVICEADDED:
		std::printf("controller added: index=%d\n", event.cdevice.which);
		break;
	case SDL_CONTROLLERDEVICEREMOVED:
		std::printf("controller removed: id=%d\n", event.cdevice.which);
		break;
	case SDL_CONTROLLERBUTTONDOWN:
	case SDL_CONTROLLERBUTTONUP:
		std::printf("controller button %s: id=%d button=%d\n",
				event.type == SDL_CONTROLLERBUTTONDOWN ? "down" : "up",
				event.cbutton.which, event.cbutton.button);
		break;
	case SDL_CONTROLLERAXISMOTION:
		if (event.caxis.value < -12000 || event.caxis.value > 12000) {
			std::printf("controller axis: id=%d axis=%d value=%d\n",
					event.caxis.which, event.caxis.axis, event.caxis.value);
		}
		break;
	default:
		return;
	}
	std::fflush(stdout);
}

} // namespace

int main(int argc, char **argv)
{
	(void)argc;
	(void)argv;

	Result socket_result = socketInitializeDefault();
	std::printf("Luanti Switch smoke starting, socket init result=0x%x\n", socket_result);
	std::fflush(stdout);

	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER | SDL_INIT_EVENTS) < 0) {
		log_sdl_error("SDL_Init failed");
		socketExit();
		return 1;
	}
	std::printf("SDL initialized: %u.%u.%u\n",
			SDL_MAJOR_VERSION, SDL_MINOR_VERSION, SDL_PATCHLEVEL);
	std::fflush(stdout);

	SDL_GameController *controllers[MAX_CONTROLLERS] = {};
	open_controllers(controllers);

	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

	SDL_Window *window = SDL_CreateWindow("Luanti Switch Smoke",
			SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
			1280, 720, SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN);
	if (!window) {
		log_sdl_error("SDL_CreateWindow failed");
		close_controllers(controllers);
		SDL_Quit();
		socketExit();
		return 2;
	}

	SDL_GLContext context = SDL_GL_CreateContext(window);
	if (!context) {
		log_sdl_error("SDL_GL_CreateContext failed");
		SDL_DestroyWindow(window);
		close_controllers(controllers);
		SDL_Quit();
		socketExit();
		return 3;
	}

	SDL_GL_SetSwapInterval(1);
	std::printf("GLES renderer: %s\n", glGetString(GL_RENDERER));
	std::printf("GLES version: %s\n", glGetString(GL_VERSION));
	std::printf("Smoke app should show an animated green-blue clear screen.\n");
	std::printf("Press Plus/Start, B/East, or close from hbmenu to exit early.\n");
	std::fflush(stdout);

	bool running = true;
	for (int frame = 0; frame < 1200 && running && appletMainLoop(); frame++) {
		SDL_Event event;
		while (SDL_PollEvent(&event)) {
			if (event.type == SDL_QUIT)
				running = false;
			log_controller_event(event);
			if (event.type == SDL_CONTROLLERBUTTONDOWN &&
					(event.cbutton.button == SDL_CONTROLLER_BUTTON_START ||
							event.cbutton.button == SDL_CONTROLLER_BUTTON_B)) {
				running = false;
			}
		}

		const float t = static_cast<float>(frame % 120) / 119.0f;
		glViewport(0, 0, 1280, 720);
		glClearColor(0.05f, 0.12f + 0.25f * t, 0.18f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);
		SDL_GL_SwapWindow(window);
	}

	delay_frames(8);

	std::printf("Luanti Switch smoke exiting.\n");
	std::fflush(stdout);
	SDL_GL_DeleteContext(context);
	SDL_DestroyWindow(window);
	close_controllers(controllers);
	SDL_Quit();
	socketExit();
	return 0;
}
