#!/usr/bin/env bash
set -euo pipefail

workflow_file="$1"

assert_contains() {
  local expected="$1"

  if ! grep -Fq "${expected}" "${workflow_file}"; then
    echo "Error: expected workflow snippet not found:" >&2
    printf '  %s\n' "${expected}" >&2
    exit 1
  fi
}

assert_contains './tests/ci_test/phase8_ci_targets.sh "${{ matrix.phase8_target }}"'
assert_contains 'mapfile -t targets < <(./tests/ci_test/phase8_ci_targets.sh "${{ matrix.phase8_target }}")'
assert_contains 'nix develop --accept-flake-config -c bazel test --test_output=errors "${targets[@]}"'
assert_contains 'bazel test --test_output=errors "${targets[@]}"'
