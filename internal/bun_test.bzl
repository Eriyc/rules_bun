"""Rule for running test suites with Bun."""

load("//internal:js_library.bzl", "BunSourcesInfo")


def _shell_quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"


def _bun_test_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin

    src_args = " ".join([_shell_quote(src.short_path) for src in ctx.files.srcs])
    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = launcher,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail

runfiles_dir="${{RUNFILES_DIR:-$0.runfiles}}"
bun_bin="${{runfiles_dir}}/_main/{bun_short_path}"
cd "${{runfiles_dir}}/_main"

if [[ -n "${{TESTBRIDGE_TEST_ONLY:-}}" && -n "${{COVERAGE_DIR:-}}" ]]; then
    exec "${{bun_bin}}" test {src_args} --test-name-pattern "${{TESTBRIDGE_TEST_ONLY}}" --coverage "$@"
fi
if [[ -n "${{TESTBRIDGE_TEST_ONLY:-}}" ]]; then
    exec "${{bun_bin}}" test {src_args} --test-name-pattern "${{TESTBRIDGE_TEST_ONLY}}" "$@"
fi
if [[ -n "${{COVERAGE_DIR:-}}" ]]; then
    exec "${{bun_bin}}" test {src_args} --coverage "$@"
fi
exec "${{bun_bin}}" test {src_args} "$@"
""".format(
                        bun_short_path = bun_bin.short_path,
            src_args = src_args,
        ),
    )

    transitive_files = []
    if ctx.attr.node_modules:
        transitive_files.append(ctx.attr.node_modules[DefaultInfo].files)
    for dep in ctx.attr.deps:
        if BunSourcesInfo in dep:
            transitive_files.append(dep[BunSourcesInfo].transitive_sources)
        else:
            transitive_files.append(dep[DefaultInfo].files)

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
        "deps": attr.label_list(),
        "data": attr.label_list(allow_files = True),
    },
    test = True,
    toolchains = ["//bun:toolchain_type"],
)
