#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Eq 'def _output_name\(target_name, entry\):' "${rule_file}"
grep -Eq 'return "\{\}__\{\}\\.js"\.format\(target_name, stem\)' "${rule_file}"
grep -Eq 'inputs = depset\(' "${rule_file}"
grep -Eq 'direct = \[entry\] \+ ctx\.files\.data' "${rule_file}"
