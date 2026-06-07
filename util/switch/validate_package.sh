#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

package_dir="${1:-build/switch/package}"
app_dir="${package_dir}/switch/luanti"

missing=""

require_path() {
	if [ ! -e "${app_dir}/$1" ]; then
		missing="${missing}
  ${app_dir}/$1"
	fi
}

require_nonempty_dir() {
	if [ ! -d "${app_dir}/$1" ] ||
			! find "${app_dir}/$1" -mindepth 1 -print -quit | grep -q .; then
		missing="${missing}
  ${app_dir}/$1"
	fi
}

require_path "luanti.nro"
require_path "icon.png"
require_path "icon.jpg"
require_path "control.nacp"
require_path "minetest.conf.example"
require_path "builtin/init.lua"
require_path "builtin/mainmenu/init.lua"
require_path "builtin/settingtypes.txt"
require_path "client/shaders/Irrlicht/Solid.fsh"
require_path "client/shaders/Irrlicht/Renderer2D.vsh"
require_path "textures/base/pack/logo.png"
require_nonempty_dir "fonts"
require_nonempty_dir "games/devtest/mods"
require_nonempty_dir "clientmods"

if [ -n "${missing}" ]; then
	printf 'Switch package is missing required runtime assets:%s\n' "${missing}" >&2
	exit 1
fi

printf 'Switch package layout is valid: %s\n' "${app_dir}"
