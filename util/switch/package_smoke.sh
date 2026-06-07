#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"

# shellcheck disable=SC1091
. "${script_dir}/env.sh"

build_dir="${1:-${repo_dir}/build/switch-smoke}"
package_dir="${2:-${build_dir}/package}"
app_dir="${package_dir}/switch/luanti-smoke"
elf_path="${build_dir}/luanti_switch_smoke.elf"
nro_path="${app_dir}/luanti-smoke.nro"
icon_path="${script_dir}/icon.jpg"
control_nacp_path="${app_dir}/control.nacp"

if [ ! -f "${elf_path}" ]; then
	"${script_dir}/build_smoke.sh" "${build_dir}"
fi

rm -rf "${app_dir}"
mkdir -p "${app_dir}"
nacptool --create "Luanti Smoke" "Luanti" "0.1" "${control_nacp_path}" \
	--titleid=0157c4e2607bb001
elf2nro "${elf_path}" "${nro_path}" --icon="${icon_path}" \
	--nacp="${control_nacp_path}"

printf 'Packaged Switch smoke app at %s\n' "${app_dir}"
