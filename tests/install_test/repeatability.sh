#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../nested_bazel_test.sh
source "${script_dir}/../nested_bazel_test.sh"
setup_nested_bazel_cmd

bun_path="$1"

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
  "name": "repeatability-test",
  "version": "1.0.0",
  "dependencies": {
    "is-number": "7.0.0"
  }
}
JSON

"${bun_path}" install --cwd "${fixture_dir}" >/dev/null
rm -rf "${fixture_dir}/node_modules"

cat >"${fixture_dir}/MODULE.bazel" <<EOF
module(
    name = "bun_install_repeatability_test",
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
    name = "node_modules_a",
    package_json = "//:package.json",
    bun_lockfile = "//:bun.lock",
)
bun_install_ext.install(
    name = "node_modules_b",
    package_json = "//:package.json",
    bun_lockfile = "//:bun.lock",
)
use_repo(
    bun_install_ext,
    "node_modules_a",
    "node_modules_b",
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
  "${bazel_cmd[@]}" build @node_modules_a//:node_modules @node_modules_b//:node_modules >/dev/null
)

output_base="$(cd "${fixture_dir}" && "${bazel_cmd[@]}" info output_base)"
repo_a="$(find "${output_base}/external" -maxdepth 1 -type d -name '*+node_modules_a' | head -n 1)"
repo_b="$(find "${output_base}/external" -maxdepth 1 -type d -name '*+node_modules_b' | head -n 1)"

if [[ -z ${repo_a} || -z ${repo_b} ]]; then
  echo "Unable to locate generated node_modules repositories" >&2
  exit 1
fi

snapshot_tree() {
  local root="$1"
  (
    cd "${root}"
    while IFS= read -r -d '' path; do
      local rel="${path#./}"
      if [[ -L ${path} ]]; then
        local target
        target="$(readlink "${path}")"
        target="${target//node_modules_a/node_modules}"
        target="${target//node_modules_b/node_modules}"
        printf 'L %s %s\n' "${rel}" "${target}"
      else
        printf 'F %s %s\n' "${rel}" "$(shasum -a 256 "${path}" | awk '{print $1}')"
      fi
    done < <(find . \( -type f -o -type l \) -print0 | sort -z)
  )
}

snapshot_tree "${repo_a}/node_modules" >"${workdir}/repo_a.snapshot"
snapshot_tree "${repo_b}/node_modules" >"${workdir}/repo_b.snapshot"

diff -u "${workdir}/repo_a.snapshot" "${workdir}/repo_b.snapshot"
