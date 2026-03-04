#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"
build_file="$2"

grep -Eq 'for package in ctx\.attr\.external:' "${rule_file}"
grep -Eq 'args\.add\("--external"\)' "${rule_file}"
grep -Eq 'name = "external_bundle"' "${build_file}"
grep -Eq 'external = \["left-pad"\]' "${build_file}"
