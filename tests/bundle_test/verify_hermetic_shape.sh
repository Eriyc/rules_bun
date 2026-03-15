#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Fq 'def _output_name(target_name, entry):' "${rule_file}"
grep -Fq 'stem = entry.short_path.rsplit(".", 1)[0]' "${rule_file}"
grep -Fq 'validate_hermetic_install_mode(ctx.attr, "bun_bundle")' "${rule_file}"
grep -Fq 'declare_staged_bun_build_action(' "${rule_file}"
