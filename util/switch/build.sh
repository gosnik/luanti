#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"

# shellcheck disable=SC1091
. "${script_dir}/env.sh"

build_dir="${1:-${repo_dir}/build/switch}"
if [ $# -gt 0 ]; then
	shift
fi

if [ ! -f "${DEVKITPRO}/portlibs/switch/lib/libsqlite3.a" ] ||
		[ ! -f "${DEVKITPRO}/portlibs/switch/include/sqlite3.h" ]; then
	"${script_dir}/build_sqlite.sh"
fi

cmake -S "${repo_dir}" -B "${build_dir}" \
	-DCMAKE_TOOLCHAIN_FILE="${repo_dir}/cmake/Toolchains/Switch.cmake" \
	-DBUILD_CLIENT=1 \
	-DBUILD_SERVER=0 \
	-DBUILD_UNITTESTS=0 \
	-DBUILD_BENCHMARKS=0 \
	-DBUILD_DOCUMENTATION=0 \
	-DENABLE_SOUND=1 \
	-DENABLE_GETTEXT=0 \
	-DENABLE_CURL=0 \
	-DENABLE_UPDATE_CHECKER=0 \
	-DENABLE_LTO=0 \
	-DENABLE_LUAJIT=0 \
	-DENABLE_POSTGRESQL=0 \
	-DENABLE_LEVELDB=0 \
	-DENABLE_REDIS=0 \
	-DENABLE_PROMETHEUS=0 \
	-DENABLE_SPATIAL=0 \
	-DENABLE_OPENSSL=0 \
	-DENABLE_SYSTEM_GMP=0 \
	-DENABLE_SYSTEM_JSONCPP=0 \
	-DENABLE_OPENGL=0 \
	-DENABLE_OPENGL3=0 \
	-DENABLE_GLES2=1 \
	-DRUN_IN_PLACE=1 \
	-DINSTALL_DEVTEST=1 \
	"$@"

cmake --build "${build_dir}" --parallel
