# rules_bun docs

Documentation for `rules_bun`, a Bazel ruleset for Bun.

## Ruleset layout

The repository exposes its public Bazel API from the [bun/](../bun/) package:

- `@rules_bun//bun:defs.bzl` for build rules
- `@rules_bun//bun:extensions.bzl` for Bzlmod extensions
- `@rules_bun//bun:repositories.bzl` for legacy WORKSPACE setup

Supporting material lives in:

- [examples/](../examples/) for usage samples
- [tests/](../tests/) for repository conformance and integration tests
- [docs/rules.md](rules.md) for generated build rule reference
- [docs/bun_install.md](bun_install.md) for `bun_install` extension docs

## Hermeticity

- Hermetic rule surfaces: `bun_build`, `bun_bundle`, `bun_compile`, `bun_test`
- Runfiles-only executable surface: `bun_binary`
- Reproducible but non-hermetic repository surface: `bun_install`
- Local workflow helpers: `bun_script`, `bun_dev`, `js_run_devserver`

## Rule reference

- [rules.md](rules.md)

## Bzlmod extensions

- [bun_install.md](bun_install.md)

## Typical Bzlmod setup

```starlark
bazel_dep(name = "rules_bun", version = "0.2.1")

bun_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun")

use_repo(
	bun_ext,
	"bun_linux_x64",
	"bun_linux_aarch64",
	"bun_linux_x64_musl",
	"bun_linux_aarch64_musl",
	"bun_darwin_x64",
	"bun_darwin_aarch64",
	"bun_windows_x64",
	"bun_windows_aarch64",
)

register_toolchains(
	"@rules_bun//bun:darwin_aarch64_toolchain",
	"@rules_bun//bun:darwin_x64_toolchain",
	"@rules_bun//bun:linux_aarch64_toolchain",
	"@rules_bun//bun:linux_x64_toolchain",
	"@rules_bun//bun:windows_x64_toolchain",
)
```

## Vite package scripts

Use `bun_script` for package-script driven workflows such as `dev`, `build`,
and `preview`.

The `node_modules` label below refers to dependencies installed by
`bun_install`.

```starlark
load("@rules_bun//bun:defs.bzl", "bun_script")

bun_script(
	name = "web_dev",
	script = "dev",
	package_json = "package.json",
	node_modules = "@my_workspace//:node_modules",
	data = glob([
		"src/**",
		"public/**",
		"index.html",
		"vite.config.*",
		"tsconfig*.json",
	]),
)
```

`bun_script` runs from the package directory by default and adds
`node_modules/.bin` to `PATH`.

## Build and compile

Use `bun_build` when Bun may emit a directory of outputs such as HTML, CSS,
chunks, and static assets. Use `bun_compile` for standalone executables created
with `bun build --compile`.

## Regeneration

The rule reference is generated from the public Starlark symbols in
`@rules_bun//bun:defs.bzl`:

```bash
bazel build //docs:rules_md
cp bazel-bin/docs/rules.md docs/rules.md
```
