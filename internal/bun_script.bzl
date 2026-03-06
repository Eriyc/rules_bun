"""Rule for running package.json scripts with Bun."""


def _shell_quote(value):
    return "'" + value.replace("'", "'\"'\"'") + "'"


def _bun_script_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    package_json = ctx.file.package_json

    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = launcher,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail

runfiles_dir="${{RUNFILES_DIR:-$0.runfiles}}"
workspace_root="${{runfiles_dir}}/_main"
bun_bin="${{runfiles_dir}}/_main/{bun_short_path}"
package_json="${{runfiles_dir}}/_main/{package_json_short_path}"
package_dir="$(dirname "${{package_json}}")"

node_modules_bin_dirs=()
while IFS= read -r node_modules_bin; do
    node_modules_bin_dirs+=("${{node_modules_bin}}")
done < <(find "${{runfiles_dir}}" -type d -path '*/node_modules/.bin' 2>/dev/null | sort)

if [[ ${{#node_modules_bin_dirs[@]}} -gt 0 ]]; then
    export PATH="$(IFS=:; echo "${{node_modules_bin_dirs[*]}}"):${{PATH}}"
fi

working_dir="{working_dir}"
if [[ "${{working_dir}}" == "package" ]]; then
    cd "${{package_dir}}"
else
    cd "${{workspace_root}}"
fi

exec "${{bun_bin}}" --bun run {script} "$@"
""".format(
            bun_short_path = bun_bin.short_path,
            package_json_short_path = package_json.short_path,
            working_dir = ctx.attr.working_dir,
            script = _shell_quote(ctx.attr.script),
        ),
    )

    transitive_files = []
    if ctx.attr.node_modules:
        transitive_files.append(ctx.attr.node_modules[DefaultInfo].files)

    runfiles = ctx.runfiles(
        files = [bun_bin, package_json] + ctx.files.data,
        transitive_files = depset(transitive = transitive_files),
    )

    return [
        DefaultInfo(
            executable = launcher,
            runfiles = runfiles,
        ),
    ]


bun_script = rule(
    implementation = _bun_script_impl,
    doc = """Runs a named `package.json` script with Bun as an executable target.

Use this rule to expose existing package scripts such as `dev`, `build`, or
`check` via `bazel run` without adding wrapper shell scripts.
""",
    attrs = {
        "script": attr.string(
            mandatory = True,
            doc = "Name of the `package.json` script to execute via `bun run <script>`.",
        ),
        "package_json": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Label of the `package.json` file containing the named script.",
        ),
        "node_modules": attr.label(
            doc = "Optional label providing Bun/npm package files in runfiles.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional runtime files required by the script.",
        ),
        "working_dir": attr.string(
            default = "package",
            values = ["workspace", "package"],
            doc = "Working directory at runtime: Bazel runfiles `workspace` root or the directory containing `package.json`.",
        ),
    },
    executable = True,
    toolchains = ["//bun:toolchain_type"],
)