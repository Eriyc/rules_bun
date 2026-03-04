#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Eq 'set -euo pipefail' "${rule_file}"
grep -Eq 'src_args = " "\.join\(\[_shell_quote\(src\.short_path\) for src in ctx\.files\.srcs\]\)' "${rule_file}"
grep -Eq 'exec "\$\{bun_bin\}" test \{src_args\} "\$@"' "${rule_file}"
