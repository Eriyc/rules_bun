#!/usr/bin/env bash
set -euo pipefail

if command -v bazel >/dev/null 2>&1; then
  bazel_cmd=(bazel)
elif command -v bazelisk >/dev/null 2>&1; then
  bazel_cmd=(bazelisk)
else
  echo "bazel or bazelisk is required on PATH" >&2
  exit 1
fi

find_workspace_root() {
  local candidate
  local module_path
  local script_dir

  for candidate in \
    "${TEST_SRCDIR:-}/${TEST_WORKSPACE:-}" \
    "${TEST_SRCDIR:-}/_main"; do
    if [[ -n ${candidate} && -f "${candidate}/MODULE.bazel" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  if [[ -n ${TEST_SRCDIR:-} ]]; then
    module_path="$(find "${TEST_SRCDIR}" -maxdepth 3 -name MODULE.bazel -print -quit 2>/dev/null || true)"
    if [[ -n ${module_path} ]]; then
      dirname "${module_path}"
      return 0
    fi
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  candidate="$(cd "${script_dir}/../.." && pwd -P)"
  if [[ -f "${candidate}/MODULE.bazel" ]]; then
    printf '%s\n' "${candidate}"
    return 0
  fi

  echo "Unable to locate rules_bun workspace root" >&2
  exit 1
}

rules_bun_root="$(find_workspace_root)"

run_aquery() {
  local mnemonic="$1"
  local target="$2"

  (
    cd "${rules_bun_root}" &&
      "${bazel_cmd[@]}" aquery "mnemonic(\"${mnemonic}\", ${target})" --output=textproto
  )
}

expect_line() {
  local output="$1"
  local expected="$2"

  if ! grep -Fq -- "${expected}" <<<"${output}"; then
    echo "Expected aquery output to contain: ${expected}" >&2
    exit 1
  fi
}

build_output="$(run_aquery "BunBuild" "//tests/bundle_test:advanced_site_build")"

for expected in \
  'arguments: "--target"' \
  'arguments: "node"' \
  'arguments: "--format"' \
  'arguments: "cjs"' \
  'arguments: "--production"' \
  'arguments: "--splitting"' \
  'arguments: "--root"' \
  'arguments: "tests/bundle_test/site"' \
  'arguments: "--sourcemap"' \
  'arguments: "linked"' \
  'arguments: "--banner"' \
  'arguments: "/* bundle banner */"' \
  'arguments: "--footer"' \
  'arguments: "// bundle footer"' \
  'arguments: "--public-path"' \
  'arguments: "/static/"' \
  'arguments: "--packages"' \
  'arguments: "external"' \
  'arguments: "left-pad"' \
  'arguments: "react"' \
  'arguments: "--entry-naming"' \
  'arguments: "entries/[name]-[hash].[ext]"' \
  'arguments: "--chunk-naming"' \
  'arguments: "chunks/[name]-[hash].[ext]"' \
  'arguments: "--asset-naming"' \
  'arguments: "assets/[name]-[hash].[ext]"' \
  'arguments: "--minify"' \
  'arguments: "--minify-syntax"' \
  'arguments: "--minify-whitespace"' \
  'arguments: "--minify-identifiers"' \
  'arguments: "--keep-names"' \
  'arguments: "--css-chunking"' \
  'arguments: "--conditions"' \
  'arguments: "browser"' \
  'arguments: "custom"' \
  'arguments: "--env"' \
  'arguments: "PUBLIC_*"' \
  'arguments: "process.env.NODE_ENV:\"production\""' \
  'arguments: "__DEV__:false"' \
  'arguments: "console"' \
  'arguments: "debugger"' \
  'arguments: "react_fast_refresh"' \
  'arguments: "server_components"' \
  'arguments: ".svg:file"' \
  'arguments: ".txt:text"' \
  'arguments: "--jsx-factory"' \
  'arguments: "h"' \
  'arguments: "--jsx-fragment"' \
  'arguments: "Fragment"' \
  'arguments: "--jsx-import-source"' \
  'arguments: "preact"' \
  'arguments: "--jsx-runtime"' \
  'arguments: "automatic"' \
  'arguments: "--jsx-side-effects"' \
  'arguments: "--react-fast-refresh"' \
  'arguments: "--emit-dce-annotations"' \
  'arguments: "--no-bundle"' \
  'arguments: "--app"' \
  'arguments: "--server-components"'; do
  expect_line "${build_output}" "${expected}"
done

default_root_output="$(run_aquery "BunBuild" "//tests/bundle_test:site_build_with_meta")"

for expected in \
  'arguments: "--root"' \
  'arguments: "tests/bundle_test/site"'; do
  expect_line "${default_root_output}" "${expected}"
done

compile_output="$(run_aquery "BunCompile" "//tests/bundle_test:compiled_cli_with_flags")"

for expected in \
  'arguments: "--bytecode"' \
  'arguments: "--compile-exec-argv"' \
  'arguments: "--smol"' \
  'arguments: "--inspect-wait"' \
  'arguments: "--no-compile-autoload-dotenv"' \
  'arguments: "--no-compile-autoload-bunfig"' \
  'arguments: "--compile-autoload-tsconfig"' \
  'arguments: "--compile-autoload-package-json"' \
  'arguments: "--compile-executable-path"' \
  'arguments: "tests/bundle_test/fake_cross_bun.bin"' \
  'arguments: "--windows-hide-console"' \
  'arguments: "--windows-icon"' \
  'arguments: "branding/icon.ico"' \
  'arguments: "--windows-title"' \
  'arguments: "Rules Bun Test App"' \
  'arguments: "--windows-publisher"' \
  'arguments: "rules_bun"' \
  'arguments: "--windows-version"' \
  'arguments: "1.2.3.4"' \
  'arguments: "--windows-description"' \
  'arguments: "compile flag coverage"' \
  'arguments: "--windows-copyright"' \
  'arguments: "(c) rules_bun"'; do
  expect_line "${compile_output}" "${expected}"
done
