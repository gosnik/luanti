#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

package_dir="${1:-build/switch-smoke/package}"
app_dir="${package_dir}/switch/luanti-smoke"
nro_path="${app_dir}/luanti-smoke.nro"

if [ ! -s "${nro_path}" ]; then
	printf 'Switch smoke package is missing required NRO: %s\n' "${nro_path}" >&2
	exit 1
fi

printf 'Switch smoke package layout is valid: %s\n' "${app_dir}"
