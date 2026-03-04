"""Rule for running test suites with Bun."""


def _shell_quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"


def _bun_test_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin

    src_args = " ".join([_shell_quote(src.path) for src in ctx.files.srcs])
    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = launcher,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail

extra_args=()
if [[ -n "${{TESTBRIDGE_TEST_ONLY:-}}" ]]; then
  extra_args+=("--test-name-pattern" "${{TESTBRIDGE_TEST_ONLY}}")
fi
if [[ -n "${{COVERAGE_DIR:-}}" ]]; then
  extra_args+=("--coverage")
fi
exec "{bun_bin}" test {src_args} "${{extra_args[@]}}" "$@"
""".format(
            bun_bin = bun_bin.path,
            src_args = src_args,
        ),
    )

    transitive_files = []
    if ctx.attr.node_modules:
        transitive_files.append(ctx.attr.node_modules[DefaultInfo].files)

    runfiles = ctx.runfiles(
        files = [bun_bin] + ctx.files.srcs + ctx.files.data,
        transitive_files = depset(transitive = transitive_files),
    )

    return [
        DefaultInfo(
            executable = launcher,
            runfiles = runfiles,
        ),
    ]


bun_test = rule(
    implementation = _bun_test_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs"],
        ),
        "node_modules": attr.label(),
        "data": attr.label_list(allow_files = True),
    },
    test = True,
    toolchains = ["//bun:toolchain_type"],
)
