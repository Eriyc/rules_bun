#!/usr/bin/env bash
set -euo pipefail

bun_path="$1"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

cat >"${workdir}/package.json" <<'JSON'
{
  "name": "stale-lockfile-test",
  "version": "1.0.0",
  "dependencies": {
    "left-pad": "1.3.0"
  }
}
JSON

"${bun_path}" install --cwd "${workdir}" >/dev/null

cat >"${workdir}/package.json" <<'JSON'
{
  "name": "stale-lockfile-test",
  "version": "1.0.0",
  "dependencies": {
    "left-pad": "1.1.3"
  }
}
JSON

set +e
output="$(${bun_path} install --cwd "${workdir}" --frozen-lockfile 2>&1)"
code=$?
set -e

if [[ ${code} -eq 0 ]]; then
  echo "Expected frozen lockfile install to fail when package.json changes" >&2
  exit 1
fi

if [[ ${output} != *"lockfile"* && ${output} != *"frozen"* ]]; then
  echo "Expected lockfile-related error, got:" >&2
  echo "${output}" >&2
  exit 1
fi
