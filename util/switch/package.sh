#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"

# shellcheck disable=SC1091
. "${script_dir}/env.sh"

build_dir="${1:-${repo_dir}/build/switch}"
package_dir="${2:-${build_dir}/package}"
app_dir="${package_dir}/switch/luanti"
romfs_dir="${package_dir}/romfs"
elf_path="${build_dir}/bin/luanti.elf"
if [ ! -f "${elf_path}" ]; then
	elf_path="${build_dir}/bin/luanti"
fi
nro_path="${app_dir}/luanti.nro"
icon_png_path="${repo_dir}/android/app/src/main/res/mipmap/ic_launcher.png"
icon_jpg_path="${script_dir}/icon.jpg"
control_nacp_path="${app_dir}/control.nacp"
title_id="0157c4e2607bb000"

if [ ! -f "${elf_path}" ]; then
	printf 'Missing built ELF: %s\n' "${elf_path}" >&2
	printf '%s\n' "Run util/switch/build.sh first." >&2
	exit 1
fi

rm -rf "${package_dir}"
mkdir -p "${app_dir}" "${romfs_dir}"

copy_dir() {
	src="$1"
	dst="$2"
	if [ -d "${src}" ]; then
		mkdir -p "$(dirname -- "${dst}")"
		cp -R "${src}" "${dst}"
	fi
}

copy_dir "${repo_dir}/builtin" "${app_dir}/builtin"
copy_dir "${repo_dir}/client/shaders" "${app_dir}/client/shaders"
copy_dir "${repo_dir}/client/serverlist" "${app_dir}/client/serverlist"
copy_dir "${repo_dir}/clientmods" "${app_dir}/clientmods"
copy_dir "${repo_dir}/textures/base/pack" "${app_dir}/textures/base/pack"
copy_dir "${repo_dir}/fonts" "${app_dir}/fonts"
copy_dir "${repo_dir}/games/devtest" "${app_dir}/games/devtest"
cp "${repo_dir}/minetest.conf.example" "${app_dir}/minetest.conf.example"
cp "${icon_png_path}" "${app_dir}/icon.png"
cp "${icon_jpg_path}" "${app_dir}/icon.jpg"

nacptool --create "Luanti" "Luanti" "0.1" "${control_nacp_path}" \
	--titleid="${title_id}"

cp -R "${app_dir}/." "${romfs_dir}/"

elf2nro "${elf_path}" "${nro_path}" --icon="${icon_jpg_path}" \
	--nacp="${control_nacp_path}" --romfsdir="${romfs_dir}"
rm -rf "${romfs_dir}"

printf 'Packaged Switch app at %s\n' "${app_dir}"
