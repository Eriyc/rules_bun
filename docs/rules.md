# rules_bun rule reference

This file documents the public rules exported from `@rules_bun//bun:defs.bzl`.

## bun_binary

Runs a JS/TS entry point with Bun as an executable target (`bazel run`).

Attributes:

- `entry_point` (label, required): path to the main JS/TS file to execute.
- `node_modules` (label, optional): Bun/npm package files in runfiles.
- `data` (label_list, optional): additional runtime files.
- `working_dir` (string, default: `"workspace"`, values: `"workspace" | "entry_point"`): runtime working directory.

## bun_dev

Runs a JS/TS entry point in Bun development watch mode (`bazel run`).

Attributes:

- `entry_point` (label, required): path to the main JS/TS file.
- `watch_mode` (string, default: `"watch"`, values: `"watch" | "hot"`): Bun live-reload mode.
- `restart_on` (label_list, optional): files that trigger full process restart when changed.
- `node_modules` (label, optional): Bun/npm package files in runfiles.
- `data` (label_list, optional): additional runtime files for dev process.
- `working_dir` (string, default: `"workspace"`, values: `"workspace" | "entry_point"`): runtime working directory.

## bun_bundle

Bundles one or more JS/TS entry points with Bun build.

Attributes:

- `entry_points` (label_list, required): entry files to bundle.
- `node_modules` (label, optional): Bun/npm package files for resolution.
- `deps` (label_list, optional): source/library dependencies for transitive inputs.
- `data` (label_list, optional): additional non-source files needed during bundling.
- `target` (string, default: `"browser"`, values: `"browser" | "node" | "bun"`): Bun build target.
- `format` (string, default: `"esm"`, values: `"esm" | "cjs" | "iife"`): module format.
- `minify` (bool, default: `False`): minifies bundle output.
- `sourcemap` (bool, default: `False`): emits source maps.
- `external` (string_list, optional): package names treated as external (not bundled).

## bun_test

Runs Bun tests as a Bazel test target (`bazel test`).

Attributes:

- `srcs` (label_list, required): test source files passed to `bun test`.
- `node_modules` (label, optional): Bun/npm package files in runfiles.
- `deps` (label_list, optional): library dependencies required by tests.
- `data` (label_list, optional): additional runtime files needed by tests.

## js_library

Aggregates JavaScript sources and transitive Bun source dependencies.

Attributes:

- `srcs` (label_list, optional): `.js`, `.jsx`, `.mjs`, `.cjs` files.
- `deps` (label_list, optional): dependent source libraries.

## ts_library

Aggregates TypeScript sources and transitive Bun source dependencies.

Attributes:

- `srcs` (label_list, optional): `.ts`, `.tsx` files.
- `deps` (label_list, optional): dependent source libraries.
