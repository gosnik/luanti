#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

PACKAGES="
switch-dev
devkitA64
libnx
switch-tools
switch-cmake
switch-sdl2
switch-mesa
switch-zlib
switch-zstd
switch-freetype
switch-libpng
switch-libjpeg-turbo
"

detect_pacman() {
	if command -v dkp-pacman >/dev/null 2>&1; then
		printf '%s\n' "dkp-pacman"
		return 0
	fi
	if command -v pacman >/dev/null 2>&1; then
		printf '%s\n' "pacman"
		return 0
	fi
	return 1
}

os_name="$(uname -s 2>/dev/null || printf unknown)"
pacman_cmd="$(detect_pacman || true)"

if [ -z "${pacman_cmd}" ]; then
	cat >&2 <<EOF
devkitPro pacman was not found.

Install devkitPro pacman for ${os_name} first:
  https://devkitpro.org/wiki/devkitPro_pacman

Then rerun this script.
EOF
	exit 1
fi

sudo_prefix=""
case "${os_name}" in
	MINGW*|MSYS*|CYGWIN*)
		;;
	*)
		if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
			sudo_prefix="sudo"
		fi
		;;
esac

${sudo_prefix} "${pacman_cmd}" -Sy --needed ${PACKAGES}

if ! ${sudo_prefix} "${pacman_cmd}" -S --needed switch-pkg-config; then
	printf '%s\n' "switch-pkg-config was not available; continuing with host pkg-config." >&2
fi

if ! ${sudo_prefix} "${pacman_cmd}" -S --needed switch-sqlite3; then
	printf '%s\n' "switch-sqlite3 was not available, trying switch-sqlite." >&2
	if ! ${sudo_prefix} "${pacman_cmd}" -S --needed switch-sqlite; then
		printf '%s\n' "No devkitPro Switch SQLite package was available; building SQLite from source." >&2
		"${0%/*}/build_sqlite.sh"
	fi
fi

DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
if [ -f "${DEVKITPRO}/switchvars.sh" ]; then
	# shellcheck disable=SC1090
	. "${DEVKITPRO}/switchvars.sh"
fi

for tool in aarch64-none-elf-gcc aarch64-none-elf-g++ elf2nro nxlink; do
	if ! command -v "${tool}" >/dev/null 2>&1; then
		printf 'Missing expected tool after install: %s\n' "${tool}" >&2
		exit 1
	fi
done

printf '%s\n' "devkitPro Switch toolchain is installed."
