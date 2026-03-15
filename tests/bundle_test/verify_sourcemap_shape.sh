#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../nested_bazel_test.sh
source "${script_dir}/../nested_bazel_test.sh"
setup_nested_bazel_cmd

rules_bun_root="$(find_nested_bazel_workspace_root "${BASH_SOURCE[0]}")"

cleanup() {
  local status="$1"
  trap - EXIT
  shutdown_nested_bazel_workspace "${rules_bun_root}"
  exit "${status}"
}
trap 'cleanup $?' EXIT

bundle_output="$(
  cd "${rules_bun_root}" &&
    "${bazel_cmd[@]}" aquery 'mnemonic("BunBundle", //tests/bundle_test/sourcemap_case:sourcemap_bundle)' --output=textproto
)"

count="$(grep -Fc 'arguments: "--sourcemap"' <<<"${bundle_output}")"
if [[ ${count} != "1" ]]; then
  echo "Expected bun_bundle(sourcemap = True) to emit exactly one --sourcemap flag, got ${count}" >&2
  exit 1
fi

grep -Fq 'arguments: "--outfile"' <<<"${bundle_output}"
grep -Fq 'arguments: "tests/bundle_test/sourcemap_case/entry.ts"' <<<"${bundle_output}"
