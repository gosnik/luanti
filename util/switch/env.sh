#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
SWITCHVARS="${DEVKITPRO}/switchvars.sh"

if [ -f "${SWITCHVARS}" ]; then
	# shellcheck disable=SC1090
	. "${SWITCHVARS}"
else
	export DEVKITPRO
	export DEVKITA64="${DEVKITA64:-${DEVKITPRO}/devkitA64}"
	export PATH="${DEVKITA64}/bin:${DEVKITPRO}/tools/bin:${PATH}"
fi

export DEVKITPRO="${DEVKITPRO}"
export DEVKITA64="${DEVKITA64:-${DEVKITPRO}/devkitA64}"
export PKG_CONFIG_PATH="${DEVKITPRO}/portlibs/switch/lib/pkgconfig:${DEVKITPRO}/libnx/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

missing=""
for tool in aarch64-none-elf-gcc aarch64-none-elf-g++ elf2nro nacptool nxlink cmake; do
	if ! command -v "${tool}" >/dev/null 2>&1; then
		missing="${missing} ${tool}"
	fi
done

if [ -n "${missing}" ]; then
	printf '%s\n' "Missing Switch build tools:${missing}" >&2
	printf '%s\n' "Run util/switch/install_devkitpro.sh, then source this file again." >&2
	return 1 2>/dev/null || exit 1
fi

printf 'DEVKITPRO=%s\n' "${DEVKITPRO}"
printf 'DEVKITA64=%s\n' "${DEVKITA64}"
