# rules_bun

Bazel rules for bun.

## Current status

Phase 1 bootstrap is in place:

- Bun toolchain rule and provider (`/bun/toolchain.bzl`)
- Platform-specific Bun repository downloads (`/bun/repositories.bzl`)
- Toolchain declarations and registration targets (`/bun/BUILD.bazel`)
- Smoke test for `bun --version` (`//tests/toolchain_test:bun_version_test`)
