#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Eq 'files = \[bun_bin\] \+ ctx\.files\.srcs \+ ctx\.files\.data' "${rule_file}"
grep -Eq '"srcs": attr\.label_list\(' "${rule_file}"
