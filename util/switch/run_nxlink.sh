#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"

usage() {
	cat <<EOF
Usage:
  util/switch/run_nxlink.sh [SWITCH_ADDRESS]
  util/switch/run_nxlink.sh [--build-dir DIR] [--package-dir DIR] [--ip SWITCH_ADDRESS] [--log-file FILE]

If the package is missing, this script runs util/switch/package.sh first.
EOF
}

build_dir="${repo_dir}/build/switch"
package_dir=""
switch_ip=""
log_file=""

if [ "$#" -eq 1 ]; then
	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
		*/*)
			build_dir="$1"
			;;
		*)
			if [ -d "$1" ]; then
				build_dir="$1"
			else
				switch_ip="$1"
			fi
			;;
	esac
else
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--build-dir)
				[ "$#" -ge 2 ] || { usage >&2; exit 1; }
				build_dir="$2"
				shift 2
				;;
			--package-dir)
				[ "$#" -ge 2 ] || { usage >&2; exit 1; }
				package_dir="$2"
				shift 2
				;;
			--ip|-a)
				[ "$#" -ge 2 ] || { usage >&2; exit 1; }
				switch_ip="$2"
				shift 2
				;;
			--log-file)
				[ "$#" -ge 2 ] || { usage >&2; exit 1; }
				log_file="$2"
				shift 2
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				usage >&2
				exit 1
				;;
		esac
	done
fi

# shellcheck disable=SC1091
. "${script_dir}/env.sh"

package_dir="${package_dir:-${build_dir}/package}"
nro_path="${package_dir}/switch/luanti/luanti.nro"

if [ ! -f "${nro_path}" ]; then
	"${script_dir}/package.sh" "${build_dir}" "${package_dir}"
fi

run_nxlink() {
	if [ -n "${switch_ip}" ]; then
		nxlink -s -a "${switch_ip}" "${nro_path}"
	else
		nxlink -s "${nro_path}"
	fi
}

if [ -n "${log_file}" ]; then
	mkdir -p "$(dirname -- "${log_file}")"
	status_file="$(mktemp "${TMPDIR:-/tmp}/luanti-nxlink-status.XXXXXX")"
	{
		set +e
		run_nxlink
		status="$?"
		set -e
		printf '%s\n' "${status}" > "${status_file}"
	} 2>&1 | tee "${log_file}"
	status="$(cat "${status_file}")"
	rm -f "${status_file}"
	exit "${status}"
else
	run_nxlink
fi
