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

bun_path="$(resolve_runfile "${1:-}")"
version="$("${bun_path}" --version)"

if [[ ! ${version} =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "Unexpected bun version output: ${version}" >&2
  exit 1
fi
