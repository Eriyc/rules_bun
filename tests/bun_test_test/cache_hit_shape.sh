#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Fq 'set -euo pipefail' "${rule_file}"
grep -Fq 'src_args = " ".join([_shell_quote(src.short_path) for src in ctx.files.srcs])' "${rule_file}"
grep -Fq 'exec "${{bun_bin}}" test {src_args} "$@"' "${rule_file}"
