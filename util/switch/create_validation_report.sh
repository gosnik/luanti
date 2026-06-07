#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

usage() {
	cat <<EOF
Usage:
  util/switch/create_validation_report.sh [--build-dir DIR] [--package-dir DIR] [--smoke-package-dir DIR] [--output FILE] [--nxlink-log FILE] [--smoke-log FILE] [--debug-log FILE] [--boot-log FILE]

Creates a Markdown report for local build artifacts and physical Switch validation notes.
EOF
}

build_dir="build/switch-docker"
package_dir="${build_dir}/package"
smoke_package_dir="${build_dir}/package-smoke"
output_file="build/switch-validation-report.md"
nxlink_log=""
smoke_log=""
debug_log=""
boot_log=""

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
		--smoke-package-dir)
			[ "$#" -ge 2 ] || { usage >&2; exit 1; }
			smoke_package_dir="$2"
			shift 2
			;;
		--output)
			[ "$#" -ge 2 ] || { usage >&2; exit 1; }
			output_file="$2"
			shift 2
			;;
		--nxlink-log)
			[ "$#" -ge 2 ] || { usage >&2; exit 1; }
			nxlink_log="$2"
			shift 2
			;;
		--smoke-log)
			[ "$#" -ge 2 ] || { usage >&2; exit 1; }
			smoke_log="$2"
			shift 2
			;;
		--debug-log)
			[ "$#" -ge 2 ] || { usage >&2; exit 1; }
			debug_log="$2"
			shift 2
			;;
		--boot-log)
			[ "$#" -ge 2 ] || { usage >&2; exit 1; }
			boot_log="$2"
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

hash_file() {
	if [ -s "$1" ]; then
		sha256sum "$1" | awk '{print $1}'
	else
		printf 'missing'
	fi
}

size_file() {
	if [ -s "$1" ]; then
		wc -c < "$1" | tr -d ' '
	else
		printf 'missing'
	fi
}

write_log_ref() {
	label="$1"
	path="$2"
	if [ -n "${path}" ]; then
		if [ -s "${path}" ]; then
			printf -- '- %s: `%s` (%s bytes, sha256 `%s`)\n' \
				"${label}" "${path}" "$(size_file "${path}")" "$(hash_file "${path}")"
		else
			printf -- '- %s: `%s` (missing or empty)\n' "${label}" "${path}"
		fi
	fi
}

mkdir -p "$(dirname -- "${output_file}")"

full_elf="${build_dir}/bin/luanti.elf"
full_nro="${package_dir}/switch/luanti/luanti.nro"
smoke_elf="${build_dir}/luanti_switch_smoke.elf"
smoke_nro="${smoke_package_dir}/switch/luanti-smoke/luanti-smoke.nro"

package_status="$(util/switch/validate_package.sh "${package_dir}" 2>&1 || true)"
smoke_status="$(util/switch/validate_smoke_package.sh "${smoke_package_dir}" 2>&1 || true)"

{
	printf '# Nintendo Switch Validation Report\n\n'
	printf 'Generated: `%s`\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

	printf '## Artifacts\n\n'
	printf '| Artifact | Path | Bytes | SHA-256 |\n'
	printf '| --- | --- | ---: | --- |\n'
	printf '| Full ELF | `%s` | %s | `%s` |\n' "${full_elf}" "$(size_file "${full_elf}")" "$(hash_file "${full_elf}")"
	printf '| Full NRO | `%s` | %s | `%s` |\n' "${full_nro}" "$(size_file "${full_nro}")" "$(hash_file "${full_nro}")"
	printf '| Smoke ELF | `%s` | %s | `%s` |\n' "${smoke_elf}" "$(size_file "${smoke_elf}")" "$(hash_file "${smoke_elf}")"
	printf '| Smoke NRO | `%s` | %s | `%s` |\n\n' "${smoke_nro}" "$(size_file "${smoke_nro}")" "$(hash_file "${smoke_nro}")"

	printf '## Package Validation\n\n'
	printf '```text\n%s\n%s\n```\n\n' "${package_status}" "${smoke_status}"

	printf '## Captured Logs\n\n'
	write_log_ref "Full client nxlink log" "${nxlink_log}"
	write_log_ref "Smoke nxlink log" "${smoke_log}"
	write_log_ref "Switch debug.txt" "${debug_log}"
	write_log_ref "Switch switch_boot.txt" "${boot_log}"
	if [ -z "${nxlink_log}${smoke_log}${debug_log}${boot_log}" ]; then
		printf -- '- No hardware logs were provided.\n'
	fi
	printf '\n'

	printf '## Hardware Checklist\n\n'
	printf '%s\n' '- [ ] Smoke app appears in hbmenu with the Luanti icon.'
	printf '%s\n' '- [ ] Smoke app shows animated green-blue clear screen.'
	printf '%s\n' '- [ ] Smoke app prints SDL/GLES/controller diagnostics.'
	printf '%s\n' '- [ ] Full client appears in hbmenu with the Luanti icon.'
	printf '%s\n' '- [ ] Full client reaches main menu.'
	printf '%s\n' '- [ ] `devtest` starts locally.'
	printf '%s\n' '- [ ] Movement, look, jump, sneak, dig, place, inventory, and hotbar controls are usable.'
	printf '%s\n' '- [ ] Full client exits cleanly.'
	printf '%s\n\n' '- [ ] `sdmc:/switch/luanti/debug.txt` is created and collected.'

	printf '## Notes\n\n'
	printf '%s\n' '- Switch model:'
	printf '%s\n' '- Firmware:'
	printf '%s\n' '- Homebrew entry point:'
	printf '%s\n' '- Controller type:'
	printf '%s\n' '- Launch method:'
} > "${output_file}"

printf 'Created Switch validation report: %s\n' "${output_file}"
