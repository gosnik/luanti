# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

if(NOT DEFINED ENV{DEVKITPRO})
	message(FATAL_ERROR "DEVKITPRO is not set. Source util/switch/env.sh or /opt/devkitpro/switchvars.sh first.")
endif()

set(DEVKITPRO "$ENV{DEVKITPRO}" CACHE PATH "devkitPro root")
set(DEVKITA64 "$ENV{DEVKITA64}" CACHE PATH "devkitA64 root")

if(NOT DEVKITA64)
	set(DEVKITA64 "${DEVKITPRO}/devkitA64" CACHE PATH "devkitA64 root" FORCE)
endif()

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_CROSSCOMPILING TRUE)
set(LUANTI_SWITCH TRUE CACHE BOOL "Build for Nintendo Switch homebrew")

set(CMAKE_C_COMPILER "${DEVKITA64}/bin/aarch64-none-elf-gcc" CACHE FILEPATH "")
set(CMAKE_CXX_COMPILER "${DEVKITA64}/bin/aarch64-none-elf-g++" CACHE FILEPATH "")
set(CMAKE_AR "${DEVKITA64}/bin/aarch64-none-elf-gcc-ar" CACHE FILEPATH "")
set(CMAKE_RANLIB "${DEVKITA64}/bin/aarch64-none-elf-gcc-ranlib" CACHE FILEPATH "")
set(CMAKE_NM "${DEVKITA64}/bin/aarch64-none-elf-gcc-nm" CACHE FILEPATH "")
set(CMAKE_STRIP "${DEVKITA64}/bin/aarch64-none-elf-strip" CACHE FILEPATH "")

set(SWITCH_PORTLIBS "${DEVKITPRO}/portlibs/switch" CACHE PATH "Switch portlibs root")
set(SWITCH_LIBNX "${DEVKITPRO}/libnx" CACHE PATH "libnx root")

list(APPEND CMAKE_PREFIX_PATH
	"${SWITCH_PORTLIBS}"
	"${SWITCH_LIBNX}")

set(CMAKE_FIND_ROOT_PATH
	"${SWITCH_PORTLIBS}"
	"${SWITCH_LIBNX}"
	"${DEVKITA64}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(ENV{PKG_CONFIG_DIR} "")
set(ENV{PKG_CONFIG_LIBDIR}
	"${SWITCH_PORTLIBS}/lib/pkgconfig:${SWITCH_LIBNX}/lib/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "")

set(SWITCH_ARCH_FLAGS "-march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft")
set(SWITCH_COMMON_FLAGS "${SWITCH_ARCH_FLAGS} -ffunction-sections -fdata-sections -fPIE")
set(SWITCH_LINK_FLAGS "${SWITCH_ARCH_FLAGS} -specs=${SWITCH_LIBNX}/switch.specs -Wl,--gc-sections")

set(CMAKE_C_FLAGS_INIT "${SWITCH_COMMON_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${SWITCH_COMMON_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${SWITCH_LINK_FLAGS}")

include_directories(SYSTEM
	"${SWITCH_PORTLIBS}/include"
	"${SWITCH_LIBNX}/include")
link_directories(
	"${SWITCH_PORTLIBS}/lib"
	"${SWITCH_LIBNX}/lib")
