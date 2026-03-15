#!/usr/bin/env bash
set -euo pipefail

default_binary="$1"
inherit_binary="$2"

run_launcher() {
  local launcher="$1"
  shift
  if [[ ${launcher} == *.cmd ]]; then
    env PATH="rules_bun_host_path_sentinel:${PATH:-}" cmd.exe /c call "${launcher}" "$@" | tr -d '\r'
    return 0
  fi
  env PATH="rules_bun_host_path_sentinel:${PATH:-}" "${launcher}" "$@"
}

default_output="$(run_launcher "${default_binary}")"
inherit_output="$(run_launcher "${inherit_binary}")"

if [[ ${default_output} != '{"hasHostSentinel":false,"canRunBun":true,"canRunBunx":true,"canRunNode":true}' ]]; then
  echo "Expected default launcher to hide host PATH, got: ${default_output}" >&2
  exit 1
fi

if [[ ${inherit_output} != '{"hasHostSentinel":true,"canRunBun":true,"canRunBunx":true,"canRunNode":true}' ]]; then
  echo "Expected inherit_host_path launcher to preserve host PATH, got: ${inherit_output}" >&2
  exit 1
fi
