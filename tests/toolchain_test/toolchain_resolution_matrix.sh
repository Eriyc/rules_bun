#!/usr/bin/env bash
set -euo pipefail

build_file="$1"

grep -Eq 'name = "linux_x86_64"' "${build_file}"
grep -Eq 'name = "linux_aarch64"' "${build_file}"
grep -Eq 'name = "darwin_x86_64"' "${build_file}"
grep -Eq 'name = "darwin_aarch64"' "${build_file}"
grep -Eq 'name = "bun_version_test"' "${build_file}"
grep -Eq 'select\(' "${build_file}"
