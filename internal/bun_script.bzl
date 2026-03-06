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
workspace_root="$(cd "${{workspace_root}}" && pwd -P)"
bun_bin="${{runfiles_dir}}/_main/{bun_short_path}"
package_json="${{runfiles_dir}}/_main/{package_json_short_path}"
package_dir="$(cd "$(dirname "${{package_json}}")" && pwd -P)"
package_rel_dir="{package_rel_dir}"

select_primary_node_modules() {{
    local selected=""
    local fallback=""
    while IFS= read -r node_modules_dir; do
        if [[ -z "${{fallback}}" ]]; then
            fallback="${{node_modules_dir}}"
        fi

        if [[ ! -d "${{node_modules_dir}}/.bun" ]]; then
            continue
        fi

        if [[ "${{node_modules_dir}}" != *"/runfiles/_main/"* ]]; then
            selected="${{node_modules_dir}}"
            break
        fi

        if [[ -z "${{selected}}" ]]; then
            selected="${{node_modules_dir}}"
        fi
    done < <(find -L "${{runfiles_dir}}" -type d -name node_modules 2>/dev/null | sort)

    if [[ -n "${{selected}}" ]]; then
        echo "${{selected}}"
    else
        echo "${{fallback}}"
    fi
}}

primary_node_modules="$(select_primary_node_modules)"

runtime_workspace="$(mktemp -d)"
cleanup_runtime_workspace() {{
    rm -rf "${{runtime_workspace}}"
}}
trap cleanup_runtime_workspace EXIT

runtime_package_dir="${{runtime_workspace}}/${{package_rel_dir}}"
mkdir -p "${{runtime_package_dir}}"
cp -RL "${{package_dir}}/." "${{runtime_package_dir}}/"

install_repo_root=""
if [[ -n "${{primary_node_modules}}" ]]; then
    install_repo_root="$(dirname "${{primary_node_modules}}")"
    ln -s "${{primary_node_modules}}" "${{runtime_workspace}}/node_modules"
fi

find_node_modules() {{
    local dir="$1"
    local root="$2"

    while [[ "$dir" == "$root"* ]]; do
        if [[ -d "$dir/node_modules" ]]; then
            echo "$dir/node_modules"
            return 0
        fi

        if [[ "$dir" == "$root" ]]; then
            break
        fi

        dir="$(dirname "$dir")"
    done

    return 1
}}

if [[ -n "${{install_repo_root}}" && -d "${{install_repo_root}}/${{package_rel_dir}}/node_modules" ]]; then
    rm -rf "${{runtime_package_dir}}/node_modules"
    ln -s "${{install_repo_root}}/${{package_rel_dir}}/node_modules" "${{runtime_package_dir}}/node_modules"
else
    resolved_node_modules="$(find_node_modules "${{runtime_package_dir}}" "${{runtime_workspace}}" || true)"
    if [[ -n "${{resolved_node_modules}}" && "${{resolved_node_modules}}" != "${{runtime_package_dir}}/node_modules" ]]; then
        rm -rf "${{runtime_package_dir}}/node_modules"
        ln -s "${{resolved_node_modules}}" "${{runtime_package_dir}}/node_modules"
    fi
fi

path_entries=()
if [[ -d "${{runtime_package_dir}}/node_modules/.bin" ]]; then
    path_entries+=("${{runtime_package_dir}}/node_modules/.bin")
fi

if [[ -d "${{runtime_workspace}}/node_modules/.bin" && "${{runtime_workspace}}/node_modules/.bin" != "${{runtime_package_dir}}/node_modules/.bin" ]]; then
    path_entries+=("${{runtime_workspace}}/node_modules/.bin")
fi

if [[ ${{#path_entries[@]}} -gt 0 ]]; then
    export PATH="$(IFS=:; echo "${{path_entries[*]}}"):${{PATH}}"
fi

working_dir="{working_dir}"
if [[ "${{working_dir}}" == "package" ]]; then
    cd "${{runtime_package_dir}}"
else
    cd "${{runtime_workspace}}"
fi

exec "${{bun_bin}}" --bun run {script} "$@"
""".format(
            bun_short_path = bun_bin.short_path,
            package_json_short_path = package_json.short_path,
            package_rel_dir = package_json.dirname,
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
`check` via `bazel run` without adding wrapper shell scripts. This is a good fit
for Vite-style workflows, where scripts like `vite dev` or `vite build` are
declared in `package.json` and expect to run from the package directory with
`node_modules/.bin` available on `PATH`.
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
            doc = "Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, in runfiles. Executables from `node_modules/.bin` are added to `PATH`, which is useful for scripts such as `vite`.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional runtime files required by the script.",
        ),
        "working_dir": attr.string(
            default = "package",
            values = ["workspace", "package"],
            doc = "Working directory at runtime: Bazel runfiles `workspace` root or the directory containing `package.json`. The default `package` mode matches tools such as Vite that resolve config and assets relative to the package directory.",
        ),
    },
    executable = True,
    toolchains = ["//bun:toolchain_type"],
)