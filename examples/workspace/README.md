# workspace example

Minimal Bun workspace-style layout with two packages:

- `@workspace/pkg-a`: exports a string helper
- `@workspace/pkg-b`: imports from `pkg-a` and prints the message

The workspace root also defines a Bun `catalog` pin for `lodash`, and both packages consume it via `"lodash": "catalog:"` to keep versions consistent across packages.

This example demonstrates building a target from a workspace-shaped directory tree with Bazel:

```bash
bazel build //examples/workspace:pkg_b_bundle
```
