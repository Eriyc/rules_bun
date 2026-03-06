# `bun_install`

`bun_install` is a Bzlmod module extension for creating an external repository
that contains a Bun-generated `node_modules/` tree.

Unlike the build rules in [rules.md](rules.md), `bun_install` is not loaded from
`@rules_bun//bun:defs.bzl`. It is loaded from
`@rules_bun//bun:extensions.bzl`, so it is documented separately.

## What it does

`bun_install`:

- runs `bun install --frozen-lockfile`
- uses your checked-in `package.json` and `bun.lock` or `bun.lockb`
- creates an external Bazel repository exposing `:node_modules`
- keeps dependency installation under Bun rather than npm

The generated repository can then be passed to rules such as `bun_script`,
`bun_binary`, `bun_bundle`, and `bun_test`.

## Usage

```starlark
bun_install_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun_install")

bun_install_ext.install(
    name = "bun_deps",
    package_json = "//:package.json",
    bun_lockfile = "//:bun.lock",
)

use_repo(bun_install_ext, "bun_deps")
```

Then reference the installed dependencies from build targets:

```starlark
load("@rules_bun//bun:defs.bzl", "bun_script")

bun_script(
    name = "web_dev",
    script = "dev",
    package_json = "package.json",
    node_modules = "@bun_deps//:node_modules",
)
```

## `install(...)` attributes

### `name`

Repository name to create.

This becomes the external repository you reference later, for example
`@bun_deps//:node_modules`.

### `package_json`

Label string pointing to the source `package.json` file.

Example:

```starlark
package_json = "//:package.json"
```

### `bun_lockfile`

Label string pointing to the Bun lockfile.

Supported lockfile names are:

- `bun.lock`
- `bun.lockb`

Example:

```starlark
bun_lockfile = "//:bun.lock"
```

### `install_inputs`

Optional list of additional files under the same package root to copy into the
install repository before Bun runs.

Use this for install-time config or patch files that Bun needs to see, for
example `.npmrc`, `bunfig.toml`, or patch files referenced by your manifest.

Example:

```starlark
install_inputs = [
    "//:.npmrc",
    "//:patches/react.patch",
]
```

`bun_install` also copies these root-level files automatically when present:

- `.npmrc`
- `bunfig.json`
- `bunfig.toml`

### `isolated_home`

Optional boolean controlling whether Bun runs with `HOME` set to the generated
repository root.

- `True` (default): more isolated install environment
- `False`: lets Bun use the host `HOME`, which can improve repeated-install
  performance when Bun's cache is home-scoped

## Notes

- `bun_install` runs Bun, not npm.
- The repository name is arbitrary. `bun_deps` is only an example.
- The generated repository exposes a standard `node_modules/` tree because that
  is the dependency layout Bun installs.
- `--frozen-lockfile` is used, so the lockfile must already be in sync with
  `package.json`.
- Additional `install_inputs` must be files under the same package root as the
  selected `package_json`.
