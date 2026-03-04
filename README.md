# rules_bun

Bazel rules for bun.

## Current status

Phase 1 bootstrap is in place:

- Bun toolchain rule and provider (`/bun/toolchain.bzl`)
- Platform-specific Bun repository downloads (`/bun/repositories.bzl`)
- Toolchain declarations and registration targets (`/bun/BUILD.bazel`)
- Smoke test for `bun --version` (`//tests/toolchain_test:bun_version_test`)

Phase 2 bootstrap is in place:

- Repository-rule based `bun_install` (`/internal/bun_install.bzl`)
- Public export via `bun/defs.bzl`
- Focused install behavior tests (`//tests/install_test:all`)

Phase 3 bootstrap is in place:

- Executable `bun_binary` rule (`/internal/bun_binary.bzl`)
- Public export via `bun/defs.bzl`
- Focused JS/TS runnable tests (`//tests/binary_test:all`)

Phase 4 bootstrap is in place:

- Test rule `bun_test` (`/internal/bun_test.bzl`)
- Public export via `bun/defs.bzl`
- Focused passing/failing test targets (`//tests/bun_test_test:all`)

Phase 5 bootstrap is in place:

- Bundle rule `bun_bundle` (`/internal/bun_bundle.bzl`)
- Public export via `bun/defs.bzl`
- Focused output/minify tests (`//tests/bundle_test:all`)

Phase 6 bootstrap is in place:

- Source grouping rules `js_library` / `ts_library` (`/internal/js_library.bzl`)
- Transitive `deps` propagation wired into `bun_bundle` and `bun_test`
- Focused dependency-propagation tests (`//tests/library_test:all`)
