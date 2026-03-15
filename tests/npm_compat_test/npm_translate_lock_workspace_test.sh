#!/usr/bin/env bash
set -euo pipefail

bun_path="${1:-bun}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../nested_bazel_test.sh
source "${script_dir}/../nested_bazel_test.sh"
setup_nested_bazel_cmd

rules_bun_root="$(find_nested_bazel_workspace_root "${BASH_SOURCE[0]}")"

workdir="$(mktemp -d)"
cleanup() {
  local status="$1"
  trap - EXIT
  shutdown_nested_bazel_workspace "${fixture_dir:-}"
  rm -rf "${workdir}"
  exit "${status}"
}
trap 'cleanup $?' EXIT

fixture_dir="${workdir}/fixture"
mkdir -p "${fixture_dir}"

cat >"${fixture_dir}/package.json" <<'JSON'
{
  "name": "npm-compat-test",
  "type": "module",
  "dependencies": {
    "is-number": "7.0.0"
  }
}
JSON

cat >"${fixture_dir}/main.js" <<'JS'
import isNumber from "is-number";

console.log(`compat:${isNumber(42)}`);
JS

"${bun_path}" install --cwd "${fixture_dir}" >/dev/null
rm -rf "${fixture_dir}/node_modules"

cat >"${fixture_dir}/MODULE.bazel" <<EOF
module(
    name = "npm_compat_test",
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

npm_ext = use_extension("@rules_bun//npm:extensions.bzl", "npm_translate_lock")
npm_ext.translate(
    name = "npm",
    package_json = "//:package.json",
    lockfile = "//:bun.lock",
)
use_repo(npm_ext, "npm")

register_toolchains(
    "@rules_bun//bun:darwin_aarch64_toolchain",
    "@rules_bun//bun:darwin_x64_toolchain",
    "@rules_bun//bun:linux_aarch64_toolchain",
    "@rules_bun//bun:linux_x64_toolchain",
    "@rules_bun//bun:windows_x64_toolchain",
)
EOF

cat >"${fixture_dir}/BUILD.bazel" <<'EOF'
load("@npm//:defs.bzl", "npm_link_all_packages")
load("@rules_bun//js:defs.bzl", "js_binary")

exports_files([
    "bun.lock",
    "main.js",
    "package.json",
])

npm_link_all_packages()

js_binary(
    name = "app",
    entry_point = "main.js",
    node_modules = ":node_modules",
)
EOF

output="$(
  cd "${fixture_dir}" &&
    "${bazel_cmd[@]}" run //:app
)"

if [[ ${output} != *"compat:true"* ]]; then
  echo "unexpected output: ${output}" >&2
  exit 1
fi

query_output="$(
  cd "${fixture_dir}" &&
    "${bazel_cmd[@]}" query //:npm__is_number
)"
if ! grep -Fxq "//:npm__is_number" <<<"${query_output}"; then
  echo "expected npm_link_all_packages to create //:npm__is_number" >&2
  exit 1
fi
