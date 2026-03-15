#!/usr/bin/env bash

setup_nested_bazel_cmd() {
  local bazel_bin
  local nested_bazel_base
  local -a scrubbed_env_vars

  if bazel_bin="$(command -v bazel 2>/dev/null)"; then
    :
  elif bazel_bin="$(command -v bazelisk 2>/dev/null)"; then
    :
  else
    echo "bazel or bazelisk is required on PATH" >&2
    exit 1
  fi

  nested_bazel_base="${TEST_TMPDIR:-${TMPDIR:-/tmp}}/rules_bun_nested_bazel"
  mkdir -p "${nested_bazel_base}"
  nested_bazel_root="$(mktemp -d "${nested_bazel_base}/session.XXXXXX")"
  mkdir -p "${nested_bazel_root}/tmp"

  scrubbed_env_vars=(
    BAZEL_TEST
    BUILD_EXECROOT
    COVERAGE_DIR
    GTEST_OUTPUT
    GTEST_SHARD_INDEX
    GTEST_SHARD_STATUS_FILE
    GTEST_TMP_DIR
    GTEST_TOTAL_SHARDS
    JAVA_RUNFILES
    PYTHON_RUNFILES
    RUNFILES_DIR
    RUNFILES_MANIFEST_FILE
    RUNFILES_MANIFEST_ONLY
    TEST_BINARY
    TEST_INFRASTRUCTURE_FAILURE_FILE
    TEST_LOGSPLITTER_OUTPUT_FILE
    TEST_PREMATURE_EXIT_FILE
    TEST_SHARD_INDEX
    TEST_SHARD_STATUS_FILE
    TEST_SRCDIR
    TEST_TARGET
    TEST_TMPDIR
    TEST_TOTAL_SHARDS
    TEST_UNDECLARED_OUTPUTS_ANNOTATIONS
    TEST_UNDECLARED_OUTPUTS_ANNOTATIONS_DIR
    TEST_UNDECLARED_OUTPUTS_DIR
    TEST_UNDECLARED_OUTPUTS_MANIFEST
    TEST_UNDECLARED_OUTPUTS_ZIP
    TEST_UNUSED_RUNFILES_LOG_FILE
    TEST_WARNINGS_OUTPUT_FILE
    XML_OUTPUT_FILE
  )

  nested_bazel_env=(env)
  for env_var in "${scrubbed_env_vars[@]}"; do
    nested_bazel_env+=("-u" "${env_var}")
  done
  nested_bazel_env+=("TMPDIR=${nested_bazel_root}/tmp")

  bazel_cmd=(
    "${nested_bazel_env[@]}"
    "${bazel_bin}"
    "--batch"
    "--ignore_all_rc_files"
    "--output_user_root=${nested_bazel_root}/output_user_root"
  )
}

find_nested_bazel_workspace_root() {
  local script_path="${1:-${BASH_SOURCE[0]}}"
  local candidate
  local script_dir

  for candidate in \
    "${TEST_SRCDIR:-}/${TEST_WORKSPACE:-}" \
    "${TEST_SRCDIR:-}/_main"; do
    if [[ -n ${candidate} && -f "${candidate}/MODULE.bazel" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  script_dir="$(cd "$(dirname "${script_path}")" && pwd -P)"
  candidate="$(cd "${script_dir}/../.." && pwd -P)"
  if [[ -f "${candidate}/MODULE.bazel" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi

  echo "Unable to locate rules_bun workspace root" >&2
  exit 1
}

shutdown_nested_bazel_workspace() {
  local workspace_dir="${1:-}"
  if [[ -n ${workspace_dir} && -d ${workspace_dir} ]]; then
    (
      cd "${workspace_dir}"
      "${bazel_cmd[@]}" shutdown >/dev/null 2>&1
    ) || true
  fi

  if [[ -n ${nested_bazel_root:-} && -d ${nested_bazel_root} ]]; then
    rm -rf "${nested_bazel_root}"
  fi
}
