Here's a comprehensive plan for implementing a Bazel-native `bun_rules` package:

---

## `bun_rules`: Bazel-Native Bun Implementation Plan

### What Is This?

A Bazel ruleset that integrates the [Bun](https://bun.sh) JavaScript runtime natively — similar to `rules_nodejs` but leveraging Bun's bundler, test runner, package manager, and runtime. The goal is hermetic, reproducible builds using Bun as the toolchain.

---

## Phase 1: Repository Skeleton & Toolchain

**Where to start.** Every Bazel ruleset begins with the toolchain — nothing else works without it.

### 1.1 Repo Structure

```
bun_rules/
├── MODULE.bazel             # Bzlmod module definition
├── WORKSPACE                # Legacy workspace support
├── BUILD.bazel
├── bun/
│   ├── repositories.bzl     # Download bun binaries per platform
│   ├── toolchain.bzl        # bun_toolchain rule
│   └── defs.bzl             # Public API re-exports
├── internal/
│   ├── bun_binary.bzl
│   ├── bun_test.bzl
│   ├── bun_install.bzl
│   └── bun_bundle.bzl
├── examples/
│   └── basic/
└── tests/
    ├── toolchain_test/
    ├── install_test/
    ├── binary_test/
    └── bundle_test/
```

### 1.2 Toolchain Rule (`toolchain.bzl`)

```python
BunToolchainInfo = provider(fields = ["bun_bin", "version"])

bun_toolchain = rule(
    implementation = _bun_toolchain_impl,
    attrs = {
        "bun": attr.label(allow_single_file = True, executable = True, cfg = "exec"),
        "version": attr.string(),
    },
)
```

### 1.3 Binary Downloads (`repositories.bzl`)

Use `http_file` to fetch platform-specific Bun binaries:

- `bun-linux-x64`, `bun-linux-aarch64`
- `bun-darwin-x64`, `bun-darwin-aarch64`
- `bun-windows-x64.exe`

Use SHA256 checksums pinned per Bun release. Register via `register_toolchains()`.

**Tests needed:**

- `toolchain_resolution_test` — assert the correct binary is selected per `--platforms`
- `bun --version` smoke test via a `sh_test`

---

## Phase 2: `bun_install` (Package Manager)

Replaces `npm install` / `yarn`. This is the highest-leverage rule because every downstream rule depends on it.

### Rule Design

```python
bun_install(
    name = "node_modules",
    package_json = "//:package.json",
    bun_lockfile = "//:bun.lockb",
)
```

- Runs `bun install --frozen-lockfile` in a sandboxed action
- Outputs a `node_modules/` directory as a `TreeArtifact`
- Must be hermetic: no network in actions (vendor or use a repository rule to pre-fetch)

### Key Challenges

- `bun.lockb` is binary — you need to commit it and treat it as a source file
- Network access during `bun install` breaks Bazel's sandbox; solve with either:
  - A **repository rule** that runs install at analysis time (like `npm_install` in rules_nodejs)
  - Or a **module extension** in Bzlmod

**Tests needed:**

- Install succeeds with a valid `package.json` + `bun.lockb`
- Build fails (with a clear error) when `bun.lockb` is out of date
- Determinism test: run install twice, assert identical output digest
- Test that `node_modules` is correctly provided to downstream rules

---

## Phase 3: `bun_binary` (Run JS/TS scripts)

```python
bun_binary(
    name = "my_script",
    entry_point = "src/main.ts",
    node_modules = "//:node_modules",
    data = glob(["src/**"]),
)
```

- Wraps `bun run <entry>` as a Bazel executable
- Provides `DefaultInfo` with a launcher script
- Handles both `.js` and `.ts` natively (no transpile step needed)

**Tests needed:**

- `bun_binary` produces a runnable target (`bazel run`)
- TypeScript entry points work without separate compilation
- `data` deps are available at runtime
- Environment variables pass through correctly

---

## Phase 4: `bun_test` (Test Runner)

```python
bun_test(
    name = "my_test",
    srcs = ["src/foo.test.ts"],
    node_modules = "//:node_modules",
)
```

- Wraps `bun test` with Bazel's test runner protocol
- Must exit with code 0/non-0 correctly
- Outputs JUnit XML for `--test_output` compatibility (use `bun test --reporter junit`)

**Tests needed:**

- Passing test suite returns exit 0
- Failing test suite returns exit non-0 (Bazel marks as FAILED)
- Test filtering via `--test_filter` works
- Coverage via `bun test --coverage` integrates with `bazel coverage`
- Tests are re-run when source files change (input tracking)
- Tests are **not** re-run when unrelated files change (cache correctness)

---

## Phase 5: `bun_bundle` (Bundler)

```python
bun_bundle(
    name = "app_bundle",
    entry_points = ["src/index.ts"],
    node_modules = "//:node_modules",
    target = "browser",   # or "node", "bun"
    format = "esm",       # or "cjs", "iife"
    minify = True,
)
```

- Runs `bun build` as a Bazel action
- Outputs are declared files (JS, sourcemaps, assets)
- Supports splitting, external packages, define/env vars

**Tests needed:**

- Output file exists and has non-zero size
- `minify = True` produces smaller output than `minify = False`
- `external` packages are not bundled
- Sourcemaps are generated when requested
- Build is hermetic: same inputs → identical output digest (content hash)
- Invalid entry point produces a clear build error (not a cryptic Bazel failure)

---

## Phase 6: `js_library` / `ts_library` (Source Grouping)

Lightweight rules for grouping sources and propagating them through the dep graph:

```python
ts_library(
    name = "utils",
    srcs = glob(["src/**/*.ts"]),
    deps = [":node_modules"],
)
```

**Tests needed:**

- `deps` correctly propagate transitive sources to `bun_bundle` and `bun_test`
- Circular dep detection (or at least graceful failure)

---

## Required Tests Summary

| Category      | Test                                                        |
| ------------- | ----------------------------------------------------------- |
| Toolchain     | Correct binary resolves per platform                        |
| Toolchain     | `bun --version` executes successfully                       |
| `bun_install` | Clean install works                                         |
| `bun_install` | Stale lockfile fails with clear error                       |
| `bun_install` | Output is deterministic                                     |
| `bun_binary`  | JS entry point runs                                         |
| `bun_binary`  | TS entry point runs without compile step                    |
| `bun_binary`  | Data files available at runtime                             |
| `bun_test`    | Passing tests → exit 0                                      |
| `bun_test`    | Failing tests → exit non-0                                  |
| `bun_test`    | Cache hit: unchanged test not re-run                        |
| `bun_test`    | Cache miss: changed source triggers re-run                  |
| `bun_test`    | JUnit XML output parseable                                  |
| `bun_bundle`  | Output file produced                                        |
| `bun_bundle`  | Minification reduces output size                            |
| `bun_bundle`  | Hermetic: identical inputs → identical digest               |
| `bun_bundle`  | External packages excluded correctly                        |
| Integration   | `examples/basic` builds end-to-end with `bazel build //...` |
| Integration   | `bazel test //...` passes all tests                         |

### Gap-Closing Checklist (Concrete Targets)

Use this checklist to close the current coverage gaps with explicit test targets.

| Status  | Gap                                                        | Proposed target                    | Location                             |
| ------- | ---------------------------------------------------------- | ---------------------------------- | ------------------------------------ |
| Partial | Toolchain resolves per platform is only host-select tested | `toolchain_resolution_matrix_test` | `tests/toolchain_test/BUILD.bazel`   |
| Missing | `bun_install` deterministic output digest                  | `bun_install_determinism_test`     | `tests/install_test/BUILD.bazel`     |
| Missing | `bun_binary` runtime data files availability               | `bun_binary_data_test`             | `tests/binary_test/BUILD.bazel`      |
| Partial | `bun_test` failing suite exists but is manual-only         | `bun_test_failing_suite_test`      | `tests/bun_test_test/BUILD.bazel`    |
| Missing | `bun_test` cache hit (unchanged inputs)                    | `bun_test_cache_hit_test`          | `tests/bun_test_test/BUILD.bazel`    |
| Missing | `bun_test` cache miss (changed source)                     | `bun_test_cache_miss_test`         | `tests/bun_test_test/BUILD.bazel`    |
| Missing | `bun_test` JUnit XML parseability                          | `bun_test_junit_output_test`       | `tests/bun_test_test/BUILD.bazel`    |
| Missing | `bun_bundle` hermetic digest stability                     | `bundle_hermetic_digest_test`      | `tests/bundle_test/BUILD.bazel`      |
| Missing | `bun_bundle` external package exclusion                    | `bundle_external_exclusion_test`   | `tests/bundle_test/BUILD.bazel`      |
| Missing | `examples/basic` end-to-end build via Bazel                | `examples_basic_e2e_build_test`    | `tests/integration_test/BUILD.bazel` |
| Partial | CI currently runs `bazel test //tests/...` only            | `repo_all_targets_test`            | `tests/integration_test/BUILD.bazel` |

Recommended implementation order:

1. `bun_test_failing_suite_test` (remove/manual split) and `bun_binary_data_test`
2. `bun_install_determinism_test`, `bundle_hermetic_digest_test`
3. `bun_test_cache_hit_test`, `bun_test_cache_miss_test`, `bun_test_junit_output_test`
4. `bundle_external_exclusion_test`, `examples_basic_e2e_build_test`, `repo_all_targets_test`

---

## Development Sequence

```
1. Toolchain downloads + resolution        ← start here
2. bun_install (repository rule approach)
3. bun_binary (simplest runtime rule)
4. bun_test
5. bun_bundle
6. js_library / ts_library
7. Bzlmod module extension for installs
8. CI matrix (linux-x64, darwin-arm64, windows)
9. Docs + examples
```

---

## Where to Start Right Now

**Day 1:** Copy the pattern from [`rules_go`](https://github.com/bazelbuild/rules_go) or [`aspect-build/rules_js`](https://github.com/aspect-build/rules_js) for toolchain registration. Write `repositories.bzl` that fetches the Bun binary for your current platform only. Write a `sh_test` that calls `bun --version` and asserts it exits 0. Get that green.

**Reference implementations to study:**

- `aspect-build/rules_js` — best modern reference for JS in Bazel
- `bazelbuild/rules_nodejs` — older but battle-tested patterns
- `bazelbuild/rules_python` — excellent toolchain download pattern to copy

The toolchain is the entire foundation. Nothing else is possible without it being solid.
