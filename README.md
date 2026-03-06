# Bun rules for [Bazel](https://bazel.build)

`rules_bun` provides Bazel rules for running, testing, bundling, and developing
JavaScript and TypeScript code with Bun.

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

## Public API

`rules_bun` exports these primary rules:

- `bun_binary`
- `bun_bundle`
- `bun_dev`
- `bun_script`
- `bun_test`
- `js_library`
- `ts_library`

Reference documentation:

- Published docs site: https://eriyc.github.io/rules_bun/
- Generated build rule reference: [docs/rules.md](docs/rules.md)
- `bun_install` extension docs: [docs/bun_install.md](docs/bun_install.md)
- Docs index: [docs/index.md](docs/index.md)

To refresh generated rule docs:

```bash
bazel build //docs:rules_md && cp bazel-bin/docs/rules.md docs/rules.md
```

## Bzlmod usage

Release announcements should provide a copy-pasteable module snippet in the
standard ruleset form:

```starlark
bazel_dep(name = "rules_bun", version = "0.2.2")
```

Then add the Bun repositories and register the toolchains in `MODULE.bazel`:

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
)

use_repo(bun_install_ext, "bun_deps")
```

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

When `node_modules` is provided, executables from `node_modules/.bin` are added
to `PATH`. This label typically comes from `bun_install`, which still produces a
standard `node_modules/` directory.

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
