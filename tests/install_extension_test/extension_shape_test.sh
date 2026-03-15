#!/usr/bin/env bash
set -euo pipefail

extension_file="$1"

grep -Eq 'bun_install[[:space:]]*=[[:space:]]*module_extension\(' "${extension_file}"
grep -Eq 'tag_classes[[:space:]]*=[[:space:]]*\{"install":[[:space:]]*_install\}' "${extension_file}"
grep -Eq '"name":[[:space:]]*attr\.string\(mandatory[[:space:]]*=[[:space:]]*True\)' "${extension_file}"
grep -Eq '"package_json":[[:space:]]*attr\.label\(mandatory[[:space:]]*=[[:space:]]*True\)' "${extension_file}"
grep -Eq '"bun_lockfile":[[:space:]]*attr\.label\(mandatory[[:space:]]*=[[:space:]]*True\)' "${extension_file}"
grep -Eq '"install_inputs":[[:space:]]*attr\.label_list\(allow_files[[:space:]]*=[[:space:]]*True\)' "${extension_file}"
grep -Eq '"isolated_home":[[:space:]]*attr\.bool\(default[[:space:]]*=[[:space:]]*True\)' "${extension_file}"
grep -Eq '"ignore_scripts":[[:space:]]*attr\.bool\(default[[:space:]]*=[[:space:]]*True\)' "${extension_file}"
