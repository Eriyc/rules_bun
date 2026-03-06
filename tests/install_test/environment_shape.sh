#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Eq 'install_args = \[str\(bun_bin\), "--bun", "install", "--frozen-lockfile", "--no-progress"\]' "${rule_file}"
grep -Eq 'if repository_ctx\.attr\.isolated_home:' "${rule_file}"
grep -Eq 'environment[[:space:]]*=[[:space:]]*\{"HOME":[[:space:]]*str\(repository_ctx\.path\("\."\)\)\}' "${rule_file}"
grep -Eq '"isolated_home": attr\.bool\(default = True\)' "${rule_file}"
