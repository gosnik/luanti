#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"

usage() {
	cat <<EOF
Usage:
  util/switch/install_smoke_to_sd.sh SD_ROOT [PACKAGE_DIR]

Copies PACKAGE_DIR/switch/luanti-smoke to SD_ROOT/switch/luanti-smoke.
PACKAGE_DIR defaults to build/switch-smoke/package.
EOF
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	usage >&2
	exit 1
fi

case "$1" in
	-h|--help)
		usage
		exit 0
		;;
esac

sd_root="$1"
package_dir="${2:-${repo_dir}/build/switch-smoke/package}"
app_src="${package_dir}/switch/luanti-smoke"
app_dst="${sd_root}/switch/luanti-smoke"

if [ ! -d "${sd_root}" ]; then
	printf 'Missing SD root directory: %s\n' "${sd_root}" >&2
	exit 1
fi

"${script_dir}/validate_smoke_package.sh" "${package_dir}"

mkdir -p "${sd_root}/switch"
rm -rf "${app_dst}"
cp -R "${app_src}" "${app_dst}"

printf 'Installed Switch smoke package to %s\n' "${app_dst}"
