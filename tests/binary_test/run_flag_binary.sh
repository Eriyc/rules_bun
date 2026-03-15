#!/usr/bin/env bash
set -euo pipefail

binary="$1"

run_launcher() {
  local launcher="$1"
  shift
  if [[ ${launcher} == *.cmd ]]; then
    cmd.exe /c call "${launcher}" "$@" | tr -d '\r'
    return 0
  fi
  "${launcher}" "$@"
}

output="$(run_launcher "${binary}")"

expected='{"preloaded":"yes","env":"from-env-file","argv":["one","two"]}'

if [[ ${output} != "${expected}" ]]; then
  echo "Unexpected output from ${binary}: ${output}" >&2
  exit 1
fi
