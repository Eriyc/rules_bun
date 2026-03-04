# rules_bun docs

Documentation site for `rules_bun`.

## Rule reference

- [rules.md](rules.md)

## Regeneration

The rule reference is generated from Starlark rule docstrings:

```bash
bazel build //docs:rules_md
cp bazel-bin/docs/rules.md docs/rules.md
```
