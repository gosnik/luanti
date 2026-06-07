#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"

package_dir="${repo_dir}/build/switch/package"
output_dir="${repo_dir}/build/switch/forwarder"
name="Luanti"
publisher="Luanti"
version="0.1"
icon_path="${script_dir}/icon.jpg"
nro_sdmc="/switch/luanti/luanti.nro"
title_id=""
nton_cmd="${NTON:-nton}"

usage() {
	cat <<EOF
Usage:
  util/switch/package_forwarder.sh [PACKAGE_DIR] [OUTPUT_DIR] [options]

Options:
  --name NAME             Home menu title name. Default: Luanti
  --publisher NAME        Home menu publisher. Default: Luanti
  --version VERSION       Home menu version. Default: 0.1
  --icon PATH             Forwarder icon. Default: util/switch/icon.jpg
  --nro-sdmc PATH         SD-card NRO path. Default: /switch/luanti/luanti.nro
  --title-id HEX          16-hex title ID. Default: deterministic 05-prefixed hash
  --nton-cmd COMMAND      NTON command to run. Default: \$NTON or nton
  -h, --help              Show this help

The forwarder NSP launches the NRO already installed on the SD card. It does
not include the Luanti app payload, so install PACKAGE_DIR/switch/luanti to
sdmc:/switch/luanti before using the NSP.
EOF
}

require_value() {
	if [ $# -lt 2 ]; then
		printf 'Missing value for %s\n\n' "$1" >&2
		usage >&2
		exit 1
	fi
}

case "${1:-}" in
	-h|--help)
		usage
		exit 0
		;;
	--*)
		;;
	"")
		;;
	*)
		package_dir="$1"
		shift
		;;
esac

case "${1:-}" in
	-h|--help)
		usage
		exit 0
		;;
	--*)
		;;
	"")
		;;
	*)
		output_dir="$1"
		shift
		;;
esac

while [ $# -gt 0 ]; do
	case "$1" in
		--name)
			require_value "$@"
			name="$2"
			shift 2
			;;
		--publisher)
			require_value "$@"
			publisher="$2"
			shift 2
			;;
		--version)
			require_value "$@"
			version="$2"
			shift 2
			;;
		--icon)
			require_value "$@"
			icon_path="$2"
			shift 2
			;;
		--nro-sdmc)
			require_value "$@"
			nro_sdmc="$2"
			shift 2
			;;
		--title-id)
			require_value "$@"
			title_id="$2"
			shift 2
			;;
		--nton-cmd)
			require_value "$@"
			nton_cmd="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n\n' "$1" >&2
			usage >&2
			exit 1
			;;
	esac
done

app_dir="${package_dir}/switch/luanti"
nro_path="${app_dir}/luanti.nro"

if [ ! -s "${nro_path}" ]; then
	printf 'Missing packaged NRO: %s\n' "${nro_path}" >&2
	printf '%s\n' "Run util/switch/package.sh first." >&2
	exit 1
fi

if [ ! -f "${icon_path}" ]; then
	printf 'Missing forwarder icon: %s\n' "${icon_path}" >&2
	exit 1
fi

case "${nro_sdmc}" in
	sdmc:/*)
		;;
	/*)
		nro_sdmc="sdmc:${nro_sdmc}"
		;;
	*)
		nro_sdmc="sdmc:/${nro_sdmc}"
		;;
esac

if [ -z "${title_id}" ]; then
	if command -v sha256sum >/dev/null 2>&1; then
		path_hash="$(printf '%s%s' "${nro_sdmc}" "${nro_sdmc}" | sha256sum | awk '{print $1}')"
	else
		path_hash="$(printf '%s%s' "${nro_sdmc}" "${nro_sdmc}" | shasum -a 256 | awk '{print $1}')"
	fi
	title_id="$(python3 - "${path_hash}" <<'PY'
import sys
raw = bytes.fromhex(sys.argv[1])
value = int.from_bytes(raw[:8], "little")
title_id = 0x0100000000000000 | (value & 0x00fffffffffff000)
print(f"{title_id:016x}")
PY
)"
fi

title_id="$(printf '%s' "${title_id}" | tr 'ABCDEF' 'abcdef')"

case "${title_id}" in
	*[!0123456789abcdefABCDEF]*)
		printf 'Title ID must be hex: %s\n' "${title_id}" >&2
		exit 1
		;;
esac

if [ "$(printf '%s' "${title_id}" | wc -c | tr -d ' ')" != "16" ]; then
	printf 'Title ID must be exactly 16 hex characters: %s\n' "${title_id}" >&2
	exit 1
fi

mkdir -p "${output_dir}"
manifest_path="${output_dir}/luanti-forwarder.txt"

cat > "${manifest_path}" <<EOF
name=${name}
publisher=${publisher}
version=${version}
title_id=${title_id}
nro_path=${nro_sdmc}
local_nro=${nro_path}
icon=${icon_path}
EOF

printf 'Prepared Switch forwarder metadata at %s\n' "${manifest_path}"

if ! command -v "${nton_cmd}" >/dev/null 2>&1; then
	cat >&2 <<EOF

Cannot build NSP: NTON was not found.

Install/use an NRO-to-NSP forwarder builder and use these values:
  Name:      ${name}
  Publisher: ${publisher}
  Version:   ${version}
  Title ID:  ${title_id}
  NRO path:  ${nro_sdmc}
  Icon:      ${icon_path}

The current devkitPro Switch Docker image does not include an NSP/NCA packer.
NTON is the expected PC-side command-line builder when available.
EOF
	exit 1
fi

before_list="${output_dir}/.before-nsp-list"
after_list="${output_dir}/.after-nsp-list"
nton_output="${HOME}/Desktop/NTON"
mkdir -p "${nton_output}"
find "${nton_output}" -maxdepth 1 -type f -name '*.nsp' -print 2>/dev/null | sort > "${before_list}"

"${nton_cmd}" build "${nro_path}" \
	--sdmc "${nro_sdmc}" \
	--name "${name}" \
	--publisher "${publisher}" \
	--version "${version}" \
	--icon "${icon_path}" \
	--id "${title_id}"

find "${nton_output}" -maxdepth 1 -type f -name '*.nsp' -print 2>/dev/null | sort > "${after_list}"
nsp_path="$(comm -13 "${before_list}" "${after_list}" | tail -n 1 || true)"
rm -f "${before_list}" "${after_list}"

if [ -z "${nsp_path}" ]; then
	nsp_path="$(find "${nton_output}" -maxdepth 1 -type f -name "*${title_id}*.nsp" -print 2>/dev/null | tail -n 1 || true)"
fi

if [ -z "${nsp_path}" ] || [ ! -s "${nsp_path}" ]; then
	printf 'NTON finished, but no NSP was found in %s\n' "${nton_output}" >&2
	exit 1
fi

final_nsp="${output_dir}/$(basename -- "${nsp_path}")"
cp "${nsp_path}" "${final_nsp}"
printf 'Packaged Switch forwarder NSP at %s\n' "${final_nsp}"
