#!/usr/bin/env bash
set -euo pipefail

bun_path="$1"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

mkdir -p "${workdir}/packages/pkg-a" "${workdir}/packages/pkg-b"

cat >"${workdir}/package.json" <<'JSON'
{
  "name": "workspace-root",
  "private": true,
  "workspaces": ["packages/*"]
}
JSON

cat >"${workdir}/packages/pkg-a/package.json" <<'JSON'
{
  "name": "@workspace/pkg-a",
  "version": "1.0.0",
  "main": "index.js"
}
JSON

cat >"${workdir}/packages/pkg-a/index.js" <<'JS'
module.exports = { value: 42 };
JS

cat >"${workdir}/packages/pkg-b/package.json" <<'JSON'
{
  "name": "@workspace/pkg-b",
  "version": "1.0.0",
  "dependencies": {
    "@workspace/pkg-a": "workspace:*"
  },
  "scripts": {
    "check": "bun -e \"const { value } = require('@workspace/pkg-a'); if (value !== 42) process.exit(1)\""
  }
}
JSON

"${bun_path}" install --cwd "${workdir}" >/dev/null
rm -rf "${workdir}/node_modules" "${workdir}/packages/pkg-b/node_modules"
"${bun_path}" install --cwd "${workdir}" --frozen-lockfile >/dev/null
"${bun_path}" run --cwd "${workdir}/packages/pkg-b" check >/dev/null
