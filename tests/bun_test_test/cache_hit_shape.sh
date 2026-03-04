#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Eq 'set -euo pipefail' "${rule_file}"
grep -Eq 'src_args = " "\.join' "${rule_file}"
grep -Eq 'exec "\$\{bun_bin\}" test \{src_args\} "\$@"' "${rule_file}"
