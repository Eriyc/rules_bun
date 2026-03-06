#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Fq 'exec "${{bun_bin}}" --bun test {src_args} --test-name-pattern "${{TESTBRIDGE_TEST_ONLY}}" "$@"' "${rule_file}"
grep -Fq 'if [[ -n "${{TESTBRIDGE_TEST_ONLY:-}}" ]]' "${rule_file}"
