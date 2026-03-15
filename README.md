# Bun rules for [Bazel](https://bazel.build)

`rules_bun` provides Bazel rules for running, testing, building, compiling,
bundling, and developing JavaScript and TypeScript code with Bun.

## Repository layout

This repository follows the standard Bazel ruleset layout:

```text
/
  MODULE.bazel
  README.md
  bun/
    BUILD.bazel
    defs.bzl
    extensions.bzl
    repositories.bzl
    toolchain.bzl
  docs/
  examples/
  tests/
```

The public entrypoint for rule authors and users is `@rules_bun//bun:defs.bzl`.

Runtime launcher targets from `bun_binary`, `bun_script`, `bun_test`,
`bun_dev`, and `js_run_devserver` use native platform wrappers. Windows runtime
support is native and does not require Git Bash or MSYS.

## Public API

`rules_bun` exports these primary rules:

- `bun_binary`
- `bun_build`
- `bun_compile`
- `bun_bundle`
- `bun_dev`
- `bun_script`
- `bun_test`
- `js_binary`
- `js_test`
- `js_run_devserver`
- `js_library`
- `ts_library`

Reference documentation:

- Published docs site: https://eriyc.github.io/rules_bun/
- Generated build rule reference: [docs/rules.md](docs/rules.md)
- `bun_install` extension docs: [docs/bun_install.md](docs/bun_install.md)
- Docs index: [docs/index.md](docs/index.md)

## Hermeticity

`rules_bun` now draws a sharp line between hermetic rule surfaces and local
workflow helpers.

- Hermetic build/test surfaces: `bun_build`, `bun_bundle`, `bun_compile`, `bun_test`
- Runfiles-only executable surface: `bun_binary`
- Reproducible but non-hermetic repository fetch surface: `bun_install`
- Local workflow helpers: `bun_script`, `bun_dev`, `js_run_devserver`

Strict defaults are enabled by default:

- `bun_install` skips lifecycle scripts unless `ignore_scripts = False`
- `bun_build`, `bun_bundle`, `bun_compile`, and `bun_test` require `install_mode = "disable"`
- Runtime launchers stage hermetic `bun`, `bunx`, and `node` commands on `PATH` and do not inherit the host `PATH` unless `inherit_host_path = True`

To refresh generated rule docs:

```bash
bazel build //docs:rules_md && cp bazel-bin/docs/rules.md docs/rules.md
```

## Bzlmod usage

Release announcements should provide a copy-pasteable module snippet in the
standard ruleset form:

```starlark
bazel_dep(name = "rules_bun", version = "1.0.3")
```

Then add the Bun repositories and register the toolchains in `MODULE.bazel`:

```starlark
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

If you want Bazel-managed dependency installation, also add the module
extension for `bun_install`:

`bun_install` runs `bun install`, not `npm install`. In the example below,
`bun_deps` is just the Bazel repository name for the generated
`node_modules` tree. See [docs/bun_install.md](docs/bun_install.md) for the
full extension reference.

```starlark
bun_install_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun_install")

bun_install_ext.install(
    name = "bun_deps",
    package_json = "//:package.json",
    bun_lockfile = "//:bun.lock",
    # Optional: include extra install-time files.
    # install_inputs = ["//:.npmrc"],
    # Optional non-hermetic opt-in:
    # ignore_scripts = False,
    # isolated_home = False,
)

use_repo(bun_install_ext, "bun_deps")
```

## `rules_js` compatibility layer

`rules_bun` now exposes a Bun-backed compatibility layer for the most common
`rules_js` entrypoints:

- `@rules_bun//js:defs.bzl` exports `js_binary`, `js_test`, `js_run_devserver`,
  `js_library`, `ts_library`, and `JsInfo`.
- `@rules_bun//npm:extensions.bzl` exports `npm_translate_lock`, which creates a
  Bun-installed external repo and generates `@<repo>//:defs.bzl` with
  `npm_link_all_packages()`.

Example:

```starlark
load("@rules_bun//js:defs.bzl", "js_binary")
load("@npm//:defs.bzl", "npm_link_all_packages")

npm_link_all_packages()

js_binary(
    name = "app",
    entry_point = "src/main.ts",
    node_modules = ":node_modules",
)
```

This is a compatibility subset, not a full reimplementation of `rules_js`.
Package aliases created by `npm_link_all_packages()` use sanitized target names
such as `npm__vite` or `npm__at_types_node`.

## Legacy WORKSPACE usage

For non-Bzlmod consumers, the repository exposes a legacy setup macro in
`@rules_bun//bun:repositories.bzl`:

```starlark
load("@rules_bun//bun:repositories.bzl", "bun_register_toolchains")

bun_register_toolchains()
```

## Loading rules in BUILD files

```starlark
load(
    "@rules_bun//bun:defs.bzl",
    "bun_binary",
    "bun_build",
    "bun_compile",
    "bun_bundle",
    "bun_dev",
    "bun_script",
    "bun_test",
    "js_library",
    "ts_library",
)
```

## Common workflows

### `bun_script` for package scripts

Use `bun_script` to expose a `package.json` script as a Bazel executable.
This is the recommended way to run Vite-style `dev`, `build`, and `preview`
scripts.

```starlark
load("@rules_bun//bun:defs.bzl", "bun_script")

bun_script(
    name = "web_dev",
    script = "dev",
    package_json = "package.json",
    node_modules = "@bun_deps//:node_modules",
    data = glob([
        "src/**",
        "static/**",
        "vite.config.*",
        "svelte.config.*",
        "tsconfig*.json",
    ]),
)
```

Launcher-based runtime rules stage hermetic `bun`, `bunx`, and `node`
commands on `PATH`. When `node_modules` is provided, executables from
`node_modules/.bin` are also added to the runtime `PATH`. The host `PATH` is
not inherited unless `inherit_host_path = True`. This label typically comes
from `bun_install`, which still produces a standard `node_modules/` directory.

### `bun_build` and `bun_compile`

Use `bun_build` for general-purpose `bun build` output directories and
`bun_compile` for standalone executables built with `bun build --compile`.

```starlark
load("@rules_bun//bun:defs.bzl", "bun_build", "bun_compile")

bun_build(
    name = "site",
    entry_points = ["src/index.html"],
    data = glob(["src/**"]),
    splitting = True,
    metafile = True,
)

bun_compile(
    name = "cli",
    entry_point = "src/cli.ts",
)
```

`bun_build` exposes a directory output so Bun can emit HTML, CSS, assets, and
split chunks. `bun_compile` produces a single executable artifact and supports
explicit cross-compilation via `compile_executable`. When `root` is omitted,
`bun_build` derives a stable default from the entry point parent directory so
HTML and asset output stays inside Bazel's declared output tree.

### `bun_dev` for local development

Use `bun_dev` for long-running watch or hot-reload development targets.

```starlark
load("@rules_bun//bun:defs.bzl", "bun_dev")

bun_dev(
    name = "web_dev",
    entry_point = "src/main.ts",
    # Optional: run from the entry point directory so Bun auto-loads colocated .env files.
    # working_dir = "entry_point",
)
```

Supported development options include:

- `watch_mode = "watch"`
- `watch_mode = "hot"`
- `restart_on = [...]`
- `working_dir = "workspace" | "entry_point"`

### Working directory behavior

`bun_binary` and `bun_dev` support `working_dir`:

- `"workspace"`: run from the Bazel runfiles workspace root.
- `"entry_point"`: run from the nearest ancestor of the entry point that
  contains `.env` or `package.json`.

## Tests and examples

The repository keeps conformance and integration coverage in [tests/](tests/) and
usage samples in [examples/](examples/).

Representative example docs:

- [examples/basic/README.md](examples/basic/README.md)
- [examples/workspace/README.md](examples/workspace/README.md)
- [examples/vite_monorepo/README.md](examples/vite_monorepo/README.md)

To validate the ruleset locally:

```bash
bazel test //tests/...
```
