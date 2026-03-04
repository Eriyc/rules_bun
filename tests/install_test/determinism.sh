#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Eq 'install", "--frozen-lockfile", "--no-progress"' "${rule_file}"
grep -Eq 'repository_ctx\.symlink\(package_json, "package\.json"\)' "${rule_file}"
grep -Eq 'repository_ctx\.symlink\(bun_lockfile, "bun\.lockb"\)' "${rule_file}"
grep -Eq 'glob\(\["node_modules/\*\*"\]' "${rule_file}"
