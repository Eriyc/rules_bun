#!/usr/bin/env bash
set -euo pipefail

binary="$1"
expected="$2"

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

output="$(run_launcher "${binary}")"

if [[ ${output} != "${expected}" ]]; then
  echo "Unexpected output from ${binary}: ${output}" >&2
  exit 1
fi
