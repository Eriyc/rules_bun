#!/usr/bin/env bash
set -euo pipefail

rule_file="$1"

grep -Eq 'install", "--frozen-lockfile", "--no-progress"' "${rule_file}"
grep -Eq 'repository_ctx\.file\("package\.json", repository_ctx\.read\(package_json\)\)' "${rule_file}"
grep -Eq 'lockfile_name = bun_lockfile\.basename' "${rule_file}"
grep -Eq 'if lockfile_name not in \["bun\.lock", "bun\.lockb"\]:' "${rule_file}"
grep -Eq 'repository_ctx\.symlink\(bun_lockfile, lockfile_name\)' "${rule_file}"
grep -Eq 'glob\(\["\*\*/node_modules/\*\*"\]' "${rule_file}"
grep -Eq '_DEFAULT_INSTALL_INPUTS = \[' "${rule_file}"
grep -Eq '"install_inputs": attr\.label_list\(allow_files = True\)' "${rule_file}"
