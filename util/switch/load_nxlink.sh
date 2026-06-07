#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

usage() {
	cat <<EOF
Usage:
  util/switch/load_nxlink.sh APP_NRO SWITCH_ADDRESS
  util/switch/load_nxlink.sh --app APP_NRO --ip SWITCH_ADDRESS [--log-file FILE]

Loads an NRO app on a Switch running nxlink/netloader.
EOF
}

app_path=""
switch_ip=""
log_file=""

if [ "$#" -eq 2 ]; then
	app_path="$1"
	switch_ip="$2"
else
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--app)
				[ "$#" -ge 2 ] || { usage >&2; exit 1; }
				app_path="$2"
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

if [ -z "${app_path}" ] || [ -z "${switch_ip}" ]; then
	usage >&2
	exit 1
fi

if [ ! -f "${app_path}" ]; then
	echo "NRO not found: ${app_path}" >&2
	exit 1
fi

# shellcheck disable=SC1091
. "${script_dir}/env.sh"

run_nxlink() {
	nxlink -s -a "${switch_ip}" "${app_path}"
}

if [ -n "${log_file}" ]; then
	mkdir -p "$(dirname -- "${log_file}")"
	status_file="$(mktemp "${TMPDIR:-/tmp}/luanti-load-nxlink-status.XXXXXX")"
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
