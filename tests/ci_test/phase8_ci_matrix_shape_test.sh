#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${RUNFILES_DIR:-} && -n ${TEST_SRCDIR:-} && -d ${TEST_SRCDIR} ]]; then
  RUNFILES_DIR="${TEST_SRCDIR}"
fi
if [[ -z ${RUNFILES_DIR:-} && -z ${RUNFILES_MANIFEST_FILE:-} ]]; then
  if [[ -d "$0.runfiles" ]]; then
    RUNFILES_DIR="$0.runfiles"
  elif [[ -f "$0.runfiles_manifest" ]]; then
    RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
  elif [[ -f "$0.exe.runfiles_manifest" ]]; then
    RUNFILES_MANIFEST_FILE="$0.exe.runfiles_manifest"
  fi
fi

resolve_runfile() {
  local path="${1:-}"
  local candidate
  local resolved

  if [[ -z ${path} ]]; then
    echo "Error: missing runfile path" >&2
    exit 1
  fi
  if [[ ${path} == /* || ${path} =~ ^[A-Za-z]:[\\/] ]]; then
    printf '%s\n' "${path}"
    return 0
  fi
  if [[ -e ${path} ]]; then
    printf '%s\n' "${path}"
    return 0
  fi

  for candidate in \
    "${path}" \
    "${TEST_WORKSPACE:-}/${path}" \
    "_main/${path}"; do
    [[ -z ${candidate} ]] && continue
    if [[ -n ${RUNFILES_DIR:-} && -e "${RUNFILES_DIR}/${candidate}" ]]; then
      printf '%s\n' "${RUNFILES_DIR}/${candidate}"
      return 0
    fi
    if [[ -n ${RUNFILES_MANIFEST_FILE:-} ]]; then
      resolved="$(
        awk -v key="${candidate}" 'index($0, key " ") == 1 { print substr($0, length(key) + 2); exit }' \
          "${RUNFILES_MANIFEST_FILE}"
      )"
      if [[ -n ${resolved} ]]; then
        printf '%s\n' "${resolved}"
        return 0
      fi
    fi
  done

  echo "Error: unable to resolve runfile: ${path}" >&2
  exit 1
}

workflow_file="$(resolve_runfile "${1:-}")"
if [ -z "${workflow_file}" ]; then
  echo "Error: workflow file path required as first argument" >&2
  exit 1
fi

check_pattern() {
  local pattern="$1"
  local message="$2"
  if ! grep -Eq "${pattern}" "${workflow_file}"; then
    echo "Error: ${message}" >&2
    exit 1
  fi
}

check_pattern '^name:[[:space:]]+CI$' "missing workflow name CI"
check_pattern 'USE_BAZEL_VERSION:[[:space:]]+9\.0\.1' "missing Bazel 9.0.1 pin"
check_pattern 'os:[[:space:]]+ubuntu-latest' "missing ubuntu matrix entry"
check_pattern 'phase8_target:[[:space:]]+linux-x64' "missing linux-x64 matrix target"
check_pattern 'os:[[:space:]]+macos-14' "missing macos matrix entry"
check_pattern 'phase8_target:[[:space:]]+darwin-arm64' "missing darwin-arm64 matrix target"

has_windows_os=0
has_windows_target=0
if grep -Eq 'os:[[:space:]]+windows-latest' "${workflow_file}"; then
  has_windows_os=1
fi
if grep -Eq 'phase8_target:[[:space:]]+windows' "${workflow_file}"; then
  has_windows_target=1
fi
if [[ ${has_windows_os} -ne ${has_windows_target} ]]; then
  echo "Error: windows matrix entry and windows phase8 target must be added or removed together" >&2
  exit 1
fi
echo "CI matrix shape checks passed"
