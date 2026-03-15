"""Rule for running JS/TS scripts with Bun."""

load("//internal:bun_command.bzl", "append_flag", "append_flag_values", "append_install_mode", "append_raw_flags")
load("//internal:js_library.bzl", "collect_js_runfiles")
load("//internal:runtime_launcher.bzl", "declare_runtime_wrapper", "runfiles_path", "runtime_launcher_attrs", "write_launcher_spec")
load("//internal:workspace.bzl", "create_bun_workspace_info", "workspace_runfiles")

def _bun_binary_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    entry_point = ctx.file.entry_point
    dep_runfiles = [collect_js_runfiles(dep) for dep in ctx.attr.deps]
    workspace_info = create_bun_workspace_info(
        ctx,
        extra_files = ctx.files.data + ctx.files.preload + ctx.files.env_files + [bun_bin],
        primary_file = entry_point,
    )

    argv = ["--bun", "run"]
    append_install_mode(argv, ctx.attr.install_mode)
    append_flag(argv, "--no-env-file", ctx.attr.no_env_file)
    append_flag(argv, "--smol", ctx.attr.smol)
    append_flag_values(argv, "--conditions", ctx.attr.conditions)
    append_raw_flags(argv, ctx.attr.run_flags)

    spec_file = write_launcher_spec(ctx, {
        "version": 1,
        "kind": "bun_run",
        "bun_short_path": runfiles_path(bun_bin),
        "primary_source_short_path": runfiles_path(entry_point),
        "package_json_short_path": "",
        "install_metadata_short_path": runfiles_path(workspace_info.install_metadata_file) if workspace_info.install_metadata_file else "",
        "install_repo_runfiles_path": workspace_info.install_repo_runfiles_path,
        "node_modules_roots": workspace_info.node_modules_roots,
        "package_dir_hint": workspace_info.package_dir_hint,
        "working_dir_mode": ctx.attr.working_dir,
        "inherit_host_path": ctx.attr.inherit_host_path,
        "argv": argv,
        "args": ctx.attr.args,
        "passthrough_args": True,
        "tool_short_path": "",
        "restart_on": [],
        "watch_mode": "",
        "reporter": "",
        "coverage": False,
        "coverage_reporters": [],
        "preload_short_paths": [runfiles_path(file) for file in ctx.files.preload],
        "env_file_short_paths": [runfiles_path(file) for file in ctx.files.env_files],
        "test_short_paths": [],
    })
    launcher = declare_runtime_wrapper(ctx, bun_bin, spec_file)

    return [
        workspace_info,
        DefaultInfo(
            executable = launcher.executable,
            runfiles = workspace_runfiles(
                ctx,
                workspace_info,
                direct_files = [launcher.executable, launcher.runner, spec_file],
                transitive_files = dep_runfiles,
            ),
        ),
    ]

_BUN_BINARY_ATTRS = runtime_launcher_attrs()
_BUN_BINARY_ATTRS.update({
    "entry_point": attr.label(
        mandatory = True,
        allow_single_file = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs"],
        doc = "Path to the main JS/TS file to execute.",
    ),
    "node_modules": attr.label(
        doc = "Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, in runfiles.",
    ),
    "data": attr.label_list(
        allow_files = True,
        doc = "Additional runtime files required by the program.",
    ),
    "deps": attr.label_list(
        doc = "Library dependencies required by the program.",
    ),
    "preload": attr.label_list(
        allow_files = True,
        doc = "Modules to preload with `--preload` before running the entry point.",
    ),
    "env_files": attr.label_list(
        allow_files = True,
        doc = "Additional environment files loaded with `--env-file`.",
    ),
    "no_env_file": attr.bool(
        default = False,
        doc = "If true, disables Bun's automatic `.env` loading.",
    ),
    "smol": attr.bool(
        default = False,
        doc = "If true, enables Bun's lower-memory runtime mode.",
    ),
    "conditions": attr.string_list(
        doc = "Custom package resolve conditions passed to Bun.",
    ),
    "install_mode": attr.string(
        default = "disable",
        values = ["disable", "auto", "fallback", "force"],
        doc = "Whether Bun may auto-install missing packages at runtime.",
    ),
    "run_flags": attr.string_list(
        doc = "Additional raw flags forwarded to `bun run` before the entry point.",
    ),
    "working_dir": attr.string(
        default = "workspace",
        values = ["workspace", "entry_point"],
        doc = "Working directory at runtime: `workspace` root or nearest `entry_point` ancestor containing `.env`/`package.json`.",
    ),
    "inherit_host_path": attr.bool(
        default = False,
        doc = "If true, appends the host PATH after the staged Bun runtime tool bin and node_modules/.bin entries at runtime.",
    ),
})

bun_binary = rule(
    implementation = _bun_binary_impl,
    doc = """Runs a JS/TS entry point with Bun as an executable target.

Use this rule for non-test scripts and CLIs that should run via `bazel run`.
""",
    attrs = _BUN_BINARY_ATTRS,
    executable = True,
    toolchains = ["//bun:toolchain_type"],
)
