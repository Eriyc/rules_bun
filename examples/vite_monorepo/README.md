# Vite monorepo example

Bun workspace-style example with two Vite applications sharing one root
`bun_install` dependency installation.

Apps:

- `apps/app-a`
- `apps/app-b`

This example also exercises Bun's workspace catalog syntax:

- `workspaces.catalog` provides the default `vite` version referenced as `catalog:`
- `workspaces.catalogs.testing` provides a named catalog referenced as `catalog:testing`

Both apps run `vite` via their own `package.json` scripts while sharing the same
generated `node_modules/` tree.

Run either app with Bazel:

```bash
bazel run //examples/vite_monorepo:app_a_dev -- --host 127.0.0.1 --port 5173 --strictPort
bazel run //examples/vite_monorepo:app_b_dev -- --host 127.0.0.1 --port 5174 --strictPort
```

This example maps its `bun_install` output to the canonical `@node_modules`
repository name in `MODULE.bazel`, so `bun_script` targets don't need to hard-
code a generated repository name.
