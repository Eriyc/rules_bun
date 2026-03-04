#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Fq 'def _output_name(target_name, entry):' "${rule_file}"
grep -Fq 'return "{}__{}.js".format(target_name, stem)' "${rule_file}"
grep -Fq 'inputs = depset(' "${rule_file}"
grep -Fq 'direct = [entry] + ctx.files.data' "${rule_file}"
