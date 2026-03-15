#!/usr/bin/env bash
set -euo pipefail

script_bin="$1"

run_launcher() {
  local launcher="$1"
  shift
  if [[ ${launcher} == *.cmd ]]; then
    local command
    printf -v command '"%s"' "${launcher}"
    for arg in "$@"; do
      printf -v command '%s "%s"' "${command}" "${arg}"
    done
    cmd.exe /c "${command}" | tr -d '\r'
    return 0
  fi
  "${launcher}" "$@"
}

output="$(run_launcher "${script_bin}")"

if [[ ${output} != *"pkg-a"* ]]; then
  echo "Expected workspace run output to include pkg-a: ${output}" >&2
  exit 1
fi

if [[ ${output} == *"pkg-b"* ]]; then
  echo "Workspace filter unexpectedly included pkg-b: ${output}" >&2
  exit 1
fi
