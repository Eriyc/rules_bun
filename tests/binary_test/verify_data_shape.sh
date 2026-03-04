#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"
build_file="$2"

grep -Eq 'files = \[bun_bin, entry_point\] \+ ctx\.files\.data' "${rule_file}"
grep -Eq 'name = "hello_js_with_data_bin"' "${build_file}"
grep -Eq 'data = \["payload\.txt"\]' "${build_file}"
