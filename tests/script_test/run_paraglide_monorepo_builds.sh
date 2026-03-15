#!/usr/bin/env bash
set -euo pipefail

app_a_binary="$1"
app_b_binary="$2"
workdir="$(mktemp -d)"

cleanup() {
  rm -rf "${workdir}"
}
trap cleanup EXIT

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

verify_build() {
  local binary="$1"
  local out_dir="$2"
  local expected_title="$3"
  local expected_text="$4"

  run_launcher "${binary}" --outDir "${out_dir}" >/dev/null

  if [[ ! -f "${out_dir}/index.html" ]]; then
    echo "missing build output index.html for ${binary}" >&2
    exit 1
  fi

  if ! grep -Fq "${expected_title}" "${out_dir}/index.html"; then
    echo "missing expected title in ${out_dir}/index.html" >&2
    exit 1
  fi

  local asset
  asset="$(find "${out_dir}/assets" -type f -name '*.js' | head -n 1)"
  if [[ -z ${asset} ]]; then
    echo "missing built JS asset for ${binary}" >&2
    exit 1
  fi

  if ! grep -Fq "${expected_text}" "${asset}"; then
    echo "missing expected translated text in ${asset}" >&2
    exit 1
  fi
}

verify_build \
  "${app_a_binary}" \
  "${workdir}/app-a-dist" \
  "Paraglide monorepo app A" \
  "En gemensam oversattningskalla"

verify_build \
  "${app_b_binary}" \
  "${workdir}/app-b-dist" \
  "Paraglide monorepo app B" \
  "One shared translation source"
