"""Compatibility rule for running an executable target as a dev server."""

load("//internal:js_library.bzl", "collect_js_runfiles")
load("//internal:runtime_launcher.bzl", "declare_runtime_wrapper", "runfiles_path", "runtime_launcher_attrs", "write_launcher_spec")
load("//internal:workspace.bzl", "create_bun_workspace_info", "workspace_runfiles")

def _js_run_devserver_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    package_json = ctx.file.package_json
    dep_runfiles = [collect_js_runfiles(dep) for dep in ctx.attr.deps]
    tool_default_info = ctx.attr.tool[DefaultInfo]

    workspace_info = create_bun_workspace_info(
        ctx,
        primary_file = package_json or tool_default_info.files_to_run.executable,
        package_json = package_json,
        package_dir_hint = ctx.attr.package_dir_hint,
        extra_files = ctx.files.data + [bun_bin, tool_default_info.files_to_run.executable],
    )

    spec_file = write_launcher_spec(ctx, {
        "version": 1,
        "kind": "tool_exec",
        "bun_short_path": runfiles_path(bun_bin),
        "primary_source_short_path": runfiles_path(package_json) if package_json else runfiles_path(tool_default_info.files_to_run.executable),
        "package_json_short_path": runfiles_path(package_json) if package_json else "",
        "install_metadata_short_path": runfiles_path(workspace_info.install_metadata_file) if workspace_info.install_metadata_file else "",
        "install_repo_runfiles_path": workspace_info.install_repo_runfiles_path,
        "node_modules_roots": workspace_info.node_modules_roots,
        "package_dir_hint": ctx.attr.package_dir_hint,
        "working_dir_mode": ctx.attr.working_dir,
        "inherit_host_path": ctx.attr.inherit_host_path,
        "argv": [],
        "args": ctx.attr.args,
        "passthrough_args": True,
        "tool_short_path": runfiles_path(tool_default_info.files_to_run.executable),
        "restart_on": [],
        "watch_mode": "",
        "reporter": "",
        "coverage": False,
        "coverage_reporters": [],
        "preload_short_paths": [],
        "env_file_short_paths": [],
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
                direct_files = [launcher.executable, launcher.runner, spec_file, tool_default_info.files_to_run.executable],
                transitive_files = dep_runfiles,
            ).merge(tool_default_info.default_runfiles),
        ),
    ]

_JS_RUN_DEVSERVER_ATTRS = runtime_launcher_attrs()
_JS_RUN_DEVSERVER_ATTRS.update({
    "tool": attr.label(
        mandatory = True,
        executable = True,
        cfg = "target",
        doc = "Executable target to launch as the dev server.",
    ),
    "package_json": attr.label(
        allow_single_file = True,
        doc = "Optional package.json used to resolve the package working directory.",
    ),
    "package_dir_hint": attr.string(
        default = ".",
        doc = "Optional package-relative directory hint when package_json is not supplied.",
    ),
    "node_modules": attr.label(
        doc = "Optional label providing package files from a node_modules tree, typically produced by bun_install or npm_translate_lock, in runfiles.",
    ),
    "deps": attr.label_list(
        doc = "Library dependencies required by the dev server.",
    ),
    "data": attr.label_list(
        allow_files = True,
        doc = "Additional runtime files required by the dev server.",
    ),
    "working_dir": attr.string(
        default = "workspace",
        values = ["workspace", "package"],
        doc = "Working directory at runtime: Bazel runfiles workspace root or the resolved package directory.",
    ),
    "inherit_host_path": attr.bool(
        default = False,
        doc = "If true, appends the host PATH after the staged Bun runtime tool bin and node_modules/.bin entries at runtime.",
    ),
})

js_run_devserver = rule(
    implementation = _js_run_devserver_impl,
    doc = """Runs an executable target from a staged JS workspace.

This is a Bun-backed compatibility adapter for `rules_js`-style devserver
targets. It stages the same runtime workspace as the Bun rules, then executes
the provided tool with any default arguments. It is intended for local
development workflows rather than hermetic build execution.
""",
    attrs = _JS_RUN_DEVSERVER_ATTRS,
    executable = True,
    toolchains = ["//bun:toolchain_type"],
)
