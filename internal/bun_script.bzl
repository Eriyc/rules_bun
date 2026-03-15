"""Rule for running package.json scripts with Bun."""

load("//internal:bun_command.bzl", "append_flag", "append_flag_value", "append_flag_values", "append_install_mode", "append_raw_flags")
load("//internal:runtime_launcher.bzl", "declare_runtime_wrapper", "runfiles_path", "runtime_launcher_attrs", "write_launcher_spec")
load("//internal:workspace.bzl", "create_bun_workspace_info", "workspace_runfiles")

def _bun_script_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    package_json = ctx.file.package_json
    workspace_info = create_bun_workspace_info(
        ctx,
        extra_files = ctx.files.data + ctx.files.preload + ctx.files.env_files + [bun_bin],
        package_dir_hint = package_json.dirname or ".",
        package_json = package_json,
        primary_file = package_json,
    )

    argv = ["--bun", "run"]
    append_install_mode(argv, ctx.attr.install_mode)
    append_flag(argv, "--no-env-file", ctx.attr.no_env_file)
    append_flag(argv, "--smol", ctx.attr.smol)
    append_flag_values(argv, "--conditions", ctx.attr.conditions)
    append_flag(argv, "--workspaces", ctx.attr.workspaces)
    append_flag_values(argv, "--filter", ctx.attr.filters)
    if ctx.attr.execution_mode == "parallel":
        append_flag(argv, "--parallel", True)
    elif ctx.attr.execution_mode == "sequential":
        append_flag(argv, "--sequential", True)
    append_flag(argv, "--no-exit-on-error", ctx.attr.no_exit_on_error)
    append_flag_value(argv, "--shell", ctx.attr.shell)
    append_flag(argv, "--silent", ctx.attr.silent)
    append_raw_flags(argv, ctx.attr.run_flags)

    spec_file = write_launcher_spec(ctx, {
        "version": 1,
        "kind": "bun_run",
        "bun_short_path": runfiles_path(bun_bin),
        "primary_source_short_path": "",
        "package_json_short_path": runfiles_path(package_json),
        "install_metadata_short_path": runfiles_path(workspace_info.install_metadata_file) if workspace_info.install_metadata_file else "",
        "install_repo_runfiles_path": workspace_info.install_repo_runfiles_path,
        "node_modules_roots": workspace_info.node_modules_roots,
        "package_dir_hint": package_json.dirname or ".",
        "working_dir_mode": ctx.attr.working_dir,
        "inherit_host_path": ctx.attr.inherit_host_path,
        "argv": argv,
        "args": [ctx.attr.script] + ctx.attr.args,
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
            ),
        ),
    ]

_BUN_SCRIPT_ATTRS = runtime_launcher_attrs()
_BUN_SCRIPT_ATTRS.update({
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
        doc = "Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, in runfiles. The staged Bun runtime tool bin and executables from `node_modules/.bin` are added to `PATH`, which is useful for scripts such as `vite`.",
    ),
    "data": attr.label_list(
        allow_files = True,
        doc = "Additional runtime files required by the script.",
    ),
    "preload": attr.label_list(
        allow_files = True,
        doc = "Modules to preload with `--preload` before running the script.",
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
        doc = "Whether Bun may auto-install missing packages while running the script.",
    ),
    "filters": attr.string_list(
        doc = "Workspace package filters passed via repeated `--filter` flags.",
    ),
    "workspaces": attr.bool(
        default = False,
        doc = "If true, runs the script in all workspace packages.",
    ),
    "execution_mode": attr.string(
        default = "single",
        values = ["single", "parallel", "sequential"],
        doc = "How Bun should execute matching workspace scripts.",
    ),
    "no_exit_on_error": attr.bool(
        default = False,
        doc = "If true, Bun keeps running other workspace scripts when one fails.",
    ),
    "shell": attr.string(
        default = "",
        values = ["", "bun", "system"],
        doc = "Optional shell implementation for package scripts.",
    ),
    "silent": attr.bool(
        default = False,
        doc = "If true, suppresses Bun's command echo for package scripts.",
    ),
    "run_flags": attr.string_list(
        doc = "Additional raw flags forwarded to `bun run` before the script name.",
    ),
    "working_dir": attr.string(
        default = "package",
        values = ["workspace", "package"],
        doc = "Working directory at runtime: Bazel runfiles `workspace` root or the directory containing `package.json`. The default `package` mode matches tools such as Vite that resolve config and assets relative to the package directory.",
    ),
    "inherit_host_path": attr.bool(
        default = False,
        doc = "If true, appends the host PATH after the staged Bun runtime tool bin and node_modules/.bin entries at runtime.",
    ),
})

bun_script = rule(
    implementation = _bun_script_impl,
    doc = """Runs a named `package.json` script with Bun as an executable target.

Use this rule to expose existing package scripts such as `dev`, `build`, or
`check` via `bazel run` without adding wrapper shell scripts. This is a good fit
for Vite-style workflows, where scripts like `vite dev` or `vite build` are
declared in `package.json` and expect to run from the package directory with
the staged Bun runtime tool bin and `node_modules/.bin` on `PATH`. This is a
local workflow helper rather than a hermetic build rule.
""",
    attrs = _BUN_SCRIPT_ATTRS,
    executable = True,
    toolchains = ["//bun:toolchain_type"],
)
