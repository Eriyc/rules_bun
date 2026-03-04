# rules_bun

Bazel rules for bun.

## Use

These steps show how to consume a tagged release of `rules_bun` in a separate Bazel workspace.

### 1) Add the module dependency

In your project's `MODULE.bazel`, add:

```starlark
bazel_dep(name = "rules_bun", version = "0.0.4")

archive_override(
	module_name = "rules_bun",
	urls = ["https://github.com/Eriyc/rules_bun/archive/refs/tags/v0.0.4.tar.gz"],
	strip_prefix = "rules_bun-v0.0.4",
)
```

For channel/pre-release tags (for example `v0.0.4-rc.1`), use the matching folder prefix:

```starlark
bazel_dep(name = "rules_bun", version = "0.0.4-rc.1")

archive_override(
	module_name = "rules_bun",
	urls = ["https://github.com/Eriyc/rules_bun/archive/refs/tags/v0.0.4-rc.1.tar.gz"],
	strip_prefix = "rules_bun-v0.0.4-rc.1",
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
