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
