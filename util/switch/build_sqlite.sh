#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
if [ -f "${DEVKITPRO}/switchvars.sh" ]; then
	# shellcheck disable=SC1090
	. "${DEVKITPRO}/switchvars.sh"
fi

DEVKITA64="${DEVKITA64:-${DEVKITPRO}/devkitA64}"
prefix="${1:-${DEVKITPRO}/portlibs/switch}"
sqlite_version="${SQLITE_VERSION_NUMBER:-3530100}"
sqlite_year="${SQLITE_RELEASE_YEAR:-2026}"
sqlite_url="${SQLITE_URL:-https://www.sqlite.org/${sqlite_year}/sqlite-autoconf-${sqlite_version}.tar.gz}"

for tool in curl tar "${DEVKITA64}/bin/aarch64-none-elf-gcc" "${DEVKITA64}/bin/aarch64-none-elf-ar"; do
	if ! command -v "${tool}" >/dev/null 2>&1 && [ ! -x "${tool}" ]; then
		printf 'Missing required tool: %s\n' "${tool}" >&2
		exit 1
	fi
done

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT INT TERM

curl -L -o "${tmpdir}/sqlite.tar.gz" "${sqlite_url}"
tar -xzf "${tmpdir}/sqlite.tar.gz" -C "${tmpdir}"
srcdir="${tmpdir}/sqlite-autoconf-${sqlite_version}"

mkdir -p "${srcdir}/switch-compat/sys"
: > "${srcdir}/switch-compat/sys/ioctl.h"
sed -i.bak 's/^#define HAVE_FCHOWN 1$/#undef HAVE_FCHOWN/' "${srcdir}/sqlite3.c"

"${DEVKITA64}/bin/aarch64-none-elf-gcc" \
	-O2 \
	-march=armv8-a+crc+crypto \
	-mtune=cortex-a57 \
	-mtp=soft \
	-ffunction-sections \
	-fdata-sections \
	-fPIE \
	-I"${srcdir}/switch-compat" \
	-I"${srcdir}" \
	-DSQLITE_THREADSAFE=1 \
	-DSQLITE_OMIT_LOAD_EXTENSION \
	-DSQLITE_OMIT_WAL \
	-DSQLITE_TEMP_STORE=3 \
	-DSQLITE_DEFAULT_MEMSTATUS=0 \
	-DSQLITE_MAX_MMAP_SIZE=0 \
	-UHAVE_FCHOWN \
	-c "${srcdir}/sqlite3.c" \
	-o "${tmpdir}/sqlite3.o"

"${DEVKITA64}/bin/aarch64-none-elf-ar" rcs "${tmpdir}/libsqlite3.a" "${tmpdir}/sqlite3.o"

install_cmd="install"
if [ ! -w "${prefix}" ] && command -v sudo >/dev/null 2>&1; then
	install_cmd="sudo install"
fi

${install_cmd} -d "${prefix}/include" "${prefix}/lib"
${install_cmd} -m 0644 "${srcdir}/sqlite3.h" "${prefix}/include/sqlite3.h"
${install_cmd} -m 0644 "${srcdir}/sqlite3ext.h" "${prefix}/include/sqlite3ext.h"
${install_cmd} -m 0644 "${tmpdir}/libsqlite3.a" "${prefix}/lib/libsqlite3.a"

printf 'Installed Switch SQLite to %s\n' "${prefix}"
