#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

usage() {
	cat <<EOF
Usage:
  util/switch/collect_debug_log.sh SD_ROOT [OUTPUT_PREFIX]

Copies SD_ROOT/switch/luanti/debug.txt and switch_boot.txt to OUTPUT_PREFIX-*.txt.
OUTPUT_PREFIX defaults to build/switch-YYYYmmdd-HHMMSS.
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
app_dir="${sd_root}/switch/luanti"
timestamp="$(date +%Y%m%d-%H%M%S)"
output_prefix="${2:-build/switch-${timestamp}}"
debug_output="${output_prefix}-debug.txt"
boot_output="${output_prefix}-boot.txt"

mkdir -p "$(dirname -- "${output_prefix}")"

copy_log() {
	src="$1"
	dst="$2"
	label="$3"
	if [ ! -s "${src}" ]; then
		printf 'Missing or empty Switch %s log: %s\n' "${label}" "${src}" >&2
		return 1
	fi
	cp "${src}" "${dst}"
	printf 'Copied Switch %s log to %s\n' "${label}" "${dst}"
}

status=0
copy_log "${app_dir}/debug.txt" "${debug_output}" "debug" || status=1
copy_log "${app_dir}/switch_boot.txt" "${boot_output}" "boot" || status=1
exit "${status}"
