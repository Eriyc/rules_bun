# rules_bun

Bazel rules for bun.

## Rule reference

- Generated API docs: [docs/rules.md](docs/rules.md)
- Regenerate: `bazel build //docs:rules_md && cp bazel-bin/docs/rules.md docs/rules.md`

## Use

These steps show how to consume a tagged release of `rules_bun` in a separate Bazel workspace.

### 1) Add the module dependency

In your project's `MODULE.bazel`, add:

```starlark
bazel_dep(name = "rules_bun", version = "0.0.7")

archive_override(
	module_name = "rules_bun",
	urls = ["https://github.com/Eriyc/rules_bun/archiv0.0.5.tar.gz"],
	strip_prefix = "rules_bun-v0.0.7",
)
```

For channel/pre-release tags (for example `v0.0.7-rc.1`), use the matching folder prefix:

```starlark
bazel_dep(name = "rules_bun", version = "0.0.7-rc.1")

archive_override(
	module_name = "rules_bun",
	urls = ["https://github.com/Eriyc/rules_bun/archiv0.0.5-rc.1.tar.gz"],
	strip_prefix = "rules_bun-v0.0.7-rc.1",
)
```

Note: keep the `v` prefix in the Git tag URL and `strip_prefix`; for `bazel_dep(..., version = ...)`, use the module version string without the leading `v`.

### 2) Create Bun repositories with the extension

Still in `MODULE.bazel`, add:

```starlark
bun_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun")

use_repo(
	bun_ext,
	"bun_linux_x64",
	"bun_linux_aarch64",
	"bun_darwin_x64",
	"bun_darwin_aarch64",
	"bun_windows_x64",
)
```

### 3) Register toolchains

Also in `MODULE.bazel`, register:

```starlark
register_toolchains(
	"@rules_bun//bun:darwin_aarch64_toolchain",
	"@rules_bun//bun:darwin_x64_toolchain",
	"@rules_bun//bun:linux_aarch64_toolchain",
	"@rules_bun//bun:linux_x64_toolchain",
	"@rules_bun//bun:windows_x64_toolchain",
)
```

### 4) Load rules in `BUILD.bazel`

```starlark
load(
	"@rules_bun//bun:defs.bzl",
	"bun_binary",
	"bun_bundle",
	"bun_dev",
	"bun_test",
	"js_library",
	"ts_library",
)
```

### 5) (Optional) Use `bun_install` module extension

If you want Bazel-managed install repositories, add:

```starlark
bun_install_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun_install")

bun_install_ext.install(
	name = "npm",
	package_json = "//:package.json",
	bun_lockfile = "//:bun.lock",
)

use_repo(bun_install_ext, "npm")
```

### 6) Verify setup

Run one of your bun-backed targets, for example:

```bash
bazel test //path/to:your_bun_test
```

All `rules_bun` rule-driven Bun invocations pass `--bun`.

## Development mode (`bun_dev`)

Use `bun_dev` for long-running local development with Bun watch mode.

```starlark
load("@rules_bun//bun:defs.bzl", "bun_dev")

bun_dev(
	name = "web_dev",
	entry_point = "src/main.ts",
	# Optional: run from the entry point directory so Bun auto-loads colocated .env files.
	# working_dir = "entry_point",
)
```

Run it with:

```bash
bazel run //path/to:web_dev
```

`bun_dev` supports:

- `watch_mode = "watch"` (default) for `bun --watch`
- `watch_mode = "hot"` for `bun --hot`
- `restart_on = [...]` to force full process restarts when specific files change
- `working_dir = "workspace" | "entry_point"` (default: `workspace`)

## Runtime working directory (`bun_binary`, `bun_dev`)

`bun_binary` and `bun_dev` support `working_dir`:

- `"workspace"` (default): runs from the Bazel runfiles workspace root.
- `"entry_point"`: runs from the entry point file's directory.

Use `"entry_point"` when Bun should resolve local files such as colocated `.env` files relative to the program directory.

### Hybrid Go + Bun + protobuf workflow

For monorepos that mix Go and Bun (including FFI):

1. Run Bun app with native watch/HMR via `bun_dev`.
2. Put generated artifacts or bridge files in `restart_on` (for example generated JS/TS files from proto/go steps).
3. Rebuild Go/proto artifacts separately (for example with `ibazel build`) so their output files change.
4. `bun_dev` detects those `restart_on` changes and restarts Bun, while ordinary JS edits continue to use Bun watch/HMR without full Bazel restarts.

This keeps the fast Bun JS loop while still supporting full restarts when non-JS dependencies change.
