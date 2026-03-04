"""Rule for running JS/TS scripts with Bun in watch mode for development."""

def _bun_dev_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    entry_point = ctx.file.entry_point

    restart_watch_paths = "\n".join([path.short_path for path in ctx.files.restart_on])

    launcher = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        output = launcher,
        is_executable = True,
        content = """#!/usr/bin/env bash
set -euo pipefail

runfiles_dir="${{RUNFILES_DIR:-$0.runfiles}}"
bun_bin="${{runfiles_dir}}/_main/{bun_short_path}"
entry_point="${{runfiles_dir}}/_main/{entry_short_path}"

working_dir="{working_dir}"
if [[ "${{working_dir}}" == "entry_point" ]]; then
    cd "$(dirname "${{entry_point}}")"
else
    cd "${{runfiles_dir}}/_main"
fi

watch_mode="{watch_mode}"
if [[ "${{watch_mode}}" == "hot" ]]; then
    dev_flag="--hot"
else
    dev_flag="--watch"
fi

run_dev() {{
    exec "${{bun_bin}}" --bun "${{dev_flag}}" run "${{entry_point}}" "$@"
}}

if [[ {restart_count} -eq 0 ]]; then
    run_dev "$@"
fi

readarray -t restart_paths <<'EOF_RESTART_PATHS'
{restart_watch_paths}
EOF_RESTART_PATHS

file_mtime() {{
    local p="$1"
    if stat -f '%m' "${{p}}" >/dev/null 2>&1; then
        stat -f '%m' "${{p}}"
        return 0
    fi
    stat -c '%Y' "${{p}}"
}}

declare -A mtimes
for rel in "${{restart_paths[@]}}"; do
    path="${{runfiles_dir}}/_main/${{rel}}"
    if [[ -e "${{path}}" ]]; then
        mtimes["${{rel}}"]="$(file_mtime "${{path}}")"
    else
        mtimes["${{rel}}"]="missing"
    fi
done

child_pid=""
restart_child() {{
    if [[ -n "${{child_pid}}" ]] && kill -0 "${{child_pid}}" 2>/dev/null; then
        kill "${{child_pid}}"
        wait "${{child_pid}}" || true
    fi
    "${{bun_bin}}" --bun "${{dev_flag}}" run "${{entry_point}}" "$@" &
    child_pid=$!
}}

cleanup() {{
    if [[ -n "${{child_pid}}" ]] && kill -0 "${{child_pid}}" 2>/dev/null; then
        kill "${{child_pid}}"
        wait "${{child_pid}}" || true
    fi
}}

trap cleanup EXIT INT TERM

restart_child "$@"

while true; do
    sleep 1
    changed=0
    for rel in "${{restart_paths[@]}}"; do
        path="${{runfiles_dir}}/_main/${{rel}}"
        if [[ -e "${{path}}" ]]; then
            current="$(file_mtime "${{path}}")"
        else
            current="missing"
        fi
        if [[ "${{current}}" != "${{mtimes[${{rel}}]}}" ]]; then
            mtimes["${{rel}}"]="${{current}}"
            changed=1
        fi
    done
    if [[ "${{changed}}" -eq 1 ]]; then
        restart_child "$@"
    fi
done
""".format(
            bun_short_path = bun_bin.short_path,
            entry_short_path = entry_point.short_path,
            watch_mode = ctx.attr.watch_mode,
            working_dir = ctx.attr.working_dir,
            restart_count = len(ctx.files.restart_on),
            restart_watch_paths = restart_watch_paths,
        ),
    )

    transitive_files = []
    if ctx.attr.node_modules:
        transitive_files.append(ctx.attr.node_modules[DefaultInfo].files)

    runfiles = ctx.runfiles(
        files = [bun_bin, entry_point] + ctx.files.data + ctx.files.restart_on,
        transitive_files = depset(transitive = transitive_files),
    )

    return [
        DefaultInfo(
            executable = launcher,
            runfiles = runfiles,
        ),
    ]

bun_dev = rule(
    implementation = _bun_dev_impl,
    attrs = {
        "entry_point": attr.label(
            mandatory = True,
            allow_single_file = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs"],
        ),
        "watch_mode": attr.string(
            default = "watch",
            values = ["watch", "hot"],
        ),
        "restart_on": attr.label_list(allow_files = True),
        "node_modules": attr.label(),
        "data": attr.label_list(allow_files = True),
        "working_dir": attr.string(
            default = "workspace",
            values = ["workspace", "entry_point"],
        ),
    },
    executable = True,
    toolchains = ["//bun:toolchain_type"],
)
