#!/usr/bin/env bash
set -euo pipefail

bun_path="$1"
if [[ ${bun_path} != /* ]]; then
  bun_path="$(cd "$(dirname "${bun_path}")" && pwd -P)/$(basename "${bun_path}")"
fi
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

mkdir -p "${workdir}/packages/pkg-a" "${workdir}/packages/pkg-b" "${workdir}/packages/web"

cat >"${workdir}/package.json" <<'JSON'
{
  "name": "workspace-catalog-root",
  "private": true,
  "workspaces": {
    "packages": ["packages/*"],
    "catalog": {
      "is-number": "7.0.0",
      "vite": "5.4.14"
    },
    "catalogs": {
      "testing": {
        "vitest": "3.2.4"
      }
    }
  }
}
JSON

cat >"${workdir}/packages/pkg-a/package.json" <<'JSON'
{
  "name": "@workspace/pkg-a",
  "version": "1.0.0",
  "main": "index.js",
  "dependencies": {
    "is-number": "catalog:"
  },
  "scripts": {
    "check": "bun -e \"const version = require('is-number/package.json').version; if (version !== '7.0.0') { console.error(version); process.exit(1); }\""
  }
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
    "@workspace/pkg-a": "workspace:*",
    "is-number": "catalog:"
  },
  "scripts": {
    "check": "bun -e \"const { value } = require('@workspace/pkg-a'); const version = require('is-number/package.json').version; if (value !== 42 || version !== '7.0.0') { console.error({ value, version }); process.exit(1); }\""
  }
}
JSON

cat >"${workdir}/packages/web/package.json" <<'JSON'
{
  "name": "@workspace/web",
  "private": true,
  "devDependencies": {
    "vite": "catalog:",
    "vitest": "catalog:testing"
  },
  "scripts": {
    "check": "bun -e \"const viteVersion = require('vite/package.json').version; const vitestVersion = require('vitest/package.json').version; if (viteVersion !== '5.4.14' || vitestVersion !== '3.2.4') { console.error({ viteVersion, vitestVersion }); process.exit(1); }\""
  }
}
JSON

"${bun_path}" install --cwd "${workdir}" >/dev/null
rm -rf "${workdir}/node_modules" "${workdir}/packages/"*/node_modules
"${bun_path}" install --cwd "${workdir}" --frozen-lockfile >/dev/null

"${bun_path}" run --cwd "${workdir}/packages/pkg-a" check >/dev/null
"${bun_path}" run --cwd "${workdir}/packages/pkg-b" check >/dev/null
"${bun_path}" run --cwd "${workdir}/packages/web" check >/dev/null
