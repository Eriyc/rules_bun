"""Rule for running JS/TS scripts with Bun."""


def _bun_binary_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    entry_point = ctx.file.entry_point

    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = launcher,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail

runfiles_dir="${{RUNFILES_DIR:-$0.runfiles}}"
bun_bin="${{runfiles_dir}}/_main/{bun_short_path}"
entry_point="${{runfiles_dir}}/_main/{entry_short_path}"

exec "${{bun_bin}}" run "${{entry_point}}" "$@"
""".format(
            bun_short_path = bun_bin.short_path,
            entry_short_path = entry_point.short_path,
        ),
    )

    transitive_files = []
    if ctx.attr.node_modules:
        transitive_files.append(ctx.attr.node_modules[DefaultInfo].files)

    runfiles = ctx.runfiles(
        files = [bun_bin, entry_point] + ctx.files.data,
        transitive_files = depset(transitive = transitive_files),
    )

    return [
        DefaultInfo(
            executable = launcher,
            runfiles = runfiles,
        ),
    ]


bun_binary = rule(
    implementation = _bun_binary_impl,
    attrs = {
        "entry_point": attr.label(
            mandatory = True,
            allow_single_file = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs"],
        ),
        "node_modules": attr.label(),
        "data": attr.label_list(allow_files = True),
    },
    executable = True,
    toolchains = ["//bun:toolchain_type"],
)
