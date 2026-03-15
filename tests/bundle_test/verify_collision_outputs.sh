#!/usr/bin/env bash
set -euo pipefail

first_output="$1"
second_output="$2"

if [[ ${first_output} == "${second_output}" ]]; then
  echo "Expected distinct bundle outputs for same-basename entry points" >&2
  exit 1
fi

if [[ ! -f ${first_output} || ! -f ${second_output} ]]; then
  echo "Expected both bundle outputs to exist" >&2
  exit 1
fi

if [[ ${first_output} != *"collision_bundle__tests_bundle_test_collision_case_a_main.js" ]]; then
  echo "Unexpected first output path: ${first_output}" >&2
  exit 1
fi

if [[ ${second_output} != *"collision_bundle__tests_bundle_test_collision_case_b_main.js" ]]; then
  echo "Unexpected second output path: ${second_output}" >&2
  exit 1
fi
