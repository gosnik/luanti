#!/usr/bin/env sh
# Luanti
# SPDX-License-Identifier: LGPL-2.1-or-later

set -eu

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_dir="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"

image="${SWITCH_DOCKER_IMAGE:-devkitpro/devkita64}"
build_dir="${1:-build/switch-docker}"
if [ $# -gt 0 ]; then
	shift
fi
package_dir="${build_dir}/package"
smoke_package_dir="${build_dir}/package-smoke"

if ! command -v docker >/dev/null 2>&1; then
	printf '%s\n' "Docker is required for util/switch/verify_docker.sh." >&2
	exit 1
fi

docker run --rm \
	-v "${repo_dir}:/work" \
	-w /work \
	"${image}" \
	sh -lc "
		set -eu
		build_dir=\"\$1\"
		package_dir=\"\$2\"
		smoke_package_dir=\"\$3\"
		shift 3
		. /opt/devkitpro/switchvars.sh
		sh -n util/switch/*.sh
		util/switch/build_sqlite.sh
		util/switch/build.sh \"\$build_dir\" \"\$@\"
		util/switch/package.sh \"\$build_dir\" \"\$package_dir\"
		util/switch/validate_package.sh \"\$package_dir\"
		util/switch/build_smoke.sh \"\$build_dir\"
		util/switch/package_smoke.sh \"\$build_dir\" \"\$smoke_package_dir\"
		util/switch/validate_smoke_package.sh \"\$smoke_package_dir\"
		test -s \"\$build_dir/bin/luanti.elf\"
		test -s \"\$package_dir/switch/luanti/luanti.nro\"
		test -s \"\$build_dir/luanti_switch_smoke.elf\"
		test -s \"\$smoke_package_dir/switch/luanti-smoke/luanti-smoke.nro\"
		ls -lh \
			\"\$build_dir/bin/luanti.elf\" \
			\"\$package_dir/switch/luanti/luanti.nro\" \
			\"\$build_dir/luanti_switch_smoke.elf\" \
			\"\$smoke_package_dir/switch/luanti-smoke/luanti-smoke.nro\"
	" sh "${build_dir}" "${package_dir}" "${smoke_package_dir}" "$@"
