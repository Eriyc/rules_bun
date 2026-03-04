#!/usr/bin/env bash
set -euo pipefail

bun_path="$1"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

cat > "${workdir}/package.json" <<'JSON'
{
  "name": "clean-install-test",
  "version": "1.0.0"
}
JSON

"${bun_path}" install --cwd "${workdir}" >/dev/null
rm -rf "${workdir}/node_modules"
"${bun_path}" install --cwd "${workdir}" --frozen-lockfile >/dev/null

if [[ ! -d "${workdir}/node_modules" ]]; then
  echo "Expected node_modules to be created" >&2
  exit 1
fi
