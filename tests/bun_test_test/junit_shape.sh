#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Eq 'exec "\$\{bun_bin\}" test \{src_args\} .*"\$@"' "${rule_file}"
grep -Eq 'if \[\[ -n "\$\{TESTBRIDGE_TEST_ONLY:-\}" \]\]' "${rule_file}"
