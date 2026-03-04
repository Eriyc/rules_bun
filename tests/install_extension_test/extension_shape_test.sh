#!/usr/bin/env bash
set -euo pipefail

extension_file="$1"

grep -q 'bun_install = module_extension(' "${extension_file}"
grep -q 'tag_classes = {"install": _install}' "${extension_file}"
grep -q '"package_json": attr.string(mandatory = True)' "${extension_file}"
grep -q '"bun_lockfile": attr.string(mandatory = True)' "${extension_file}"
