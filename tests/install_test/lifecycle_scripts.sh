#!/usr/bin/env bash
set -euo pipefail

bun_path="$1"

if command -v bazel >/dev/null 2>&1; then
  bazel_cmd=(bazel)
elif command -v bazelisk >/dev/null 2>&1; then
  bazel_cmd=(bazelisk)
else
  echo "bazel or bazelisk is required on PATH" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
rules_bun_root="$(cd "${script_dir}/../.." && pwd -P)"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

fixture_dir="${workdir}/fixture"
mkdir -p "${fixture_dir}"

cat >"${fixture_dir}/package.json" <<'JSON'
{
  "name": "lifecycle-script-test",
  "version": "1.0.0",
  "dependencies": {
    "is-number": "7.0.0"
  },
  "scripts": {
    "postinstall": "bun -e \"require('node:fs').writeFileSync('postinstall.txt', 'ran')\""
  }
}
JSON

"${bun_path}" install --cwd "${fixture_dir}" >/dev/null
rm -rf "${fixture_dir}/node_modules" "${fixture_dir}/postinstall.txt"

cat >"${fixture_dir}/MODULE.bazel" <<EOF
module(
    name = "bun_install_lifecycle_scripts_test",
)

bazel_dep(name = "rules_bun", version = "0.2.2")

local_path_override(
    module_name = "rules_bun",
    path = "${rules_bun_root}",
)

bun_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun")
use_repo(
    bun_ext,
    "bun_darwin_aarch64",
    "bun_darwin_x64",
    "bun_linux_aarch64",
    "bun_linux_x64",
    "bun_windows_x64",
)

bun_install_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun_install")
bun_install_ext.install(
    name = "scripts_blocked",
    package_json = "//:package.json",
    bun_lockfile = "//:bun.lock",
)
bun_install_ext.install(
    name = "scripts_allowed",
    package_json = "//:package.json",
    bun_lockfile = "//:bun.lock",
    ignore_scripts = False,
)
use_repo(
    bun_install_ext,
    "scripts_allowed",
    "scripts_blocked",
)

register_toolchains(
    "@rules_bun//bun:darwin_aarch64_toolchain",
    "@rules_bun//bun:darwin_x64_toolchain",
    "@rules_bun//bun:linux_aarch64_toolchain",
    "@rules_bun//bun:linux_x64_toolchain",
    "@rules_bun//bun:windows_x64_toolchain",
)
EOF

cat >"${fixture_dir}/BUILD.bazel" <<'EOF'
exports_files([
    "package.json",
    "bun.lock",
])
EOF

(
  cd "${fixture_dir}"
  "${bazel_cmd[@]}" build @scripts_blocked//:node_modules @scripts_allowed//:node_modules >/dev/null
)

output_base="$(cd "${fixture_dir}" && "${bazel_cmd[@]}" info output_base)"
blocked_repo="$(find "${output_base}/external" -maxdepth 1 -type d -name '*+scripts_blocked' | head -n 1)"
allowed_repo="$(find "${output_base}/external" -maxdepth 1 -type d -name '*+scripts_allowed' | head -n 1)"

if [[ -z ${blocked_repo} || -z ${allowed_repo} ]]; then
  echo "Unable to locate generated lifecycle test repositories" >&2
  exit 1
fi

if [[ -e "${blocked_repo}/postinstall.txt" ]]; then
  echo "Lifecycle scripts should be disabled by default" >&2
  exit 1
fi

if [[ ! -f "${allowed_repo}/postinstall.txt" ]]; then
  echo "Lifecycle scripts should run when ignore_scripts = False" >&2
  exit 1
fi
