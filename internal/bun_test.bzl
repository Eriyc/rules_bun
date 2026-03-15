"""Rule for running test suites with Bun."""

load("//internal:bun_command.bzl", "append_flag", "append_flag_value", "append_install_mode", "append_raw_flags")
load("//internal:js_library.bzl", "collect_js_runfiles")
load("//internal:runtime_launcher.bzl", "declare_runtime_wrapper", "runfiles_path", "runtime_launcher_attrs", "write_launcher_spec")
load("//internal:workspace.bzl", "create_bun_workspace_info", "workspace_runfiles")

def _bun_test_impl(ctx):
    if ctx.attr.install_mode != "disable":
        fail("bun_test requires install_mode = \"disable\" for hermetic test execution")

    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    primary_file = ctx.files.srcs[0]
    dep_runfiles = [collect_js_runfiles(dep) for dep in ctx.attr.deps]
    workspace_info = create_bun_workspace_info(
        ctx,
        extra_files = ctx.files.srcs + ctx.files.data + ctx.files.preload + ctx.files.env_files + [bun_bin],
        primary_file = primary_file,
    )

    argv = ["--bun", "test"]
    append_install_mode(argv, ctx.attr.install_mode)
    append_flag(argv, "--no-env-file", ctx.attr.no_env_file)
    append_flag(argv, "--smol", ctx.attr.smol)
    append_flag_value(argv, "--timeout", str(ctx.attr.timeout_ms) if ctx.attr.timeout_ms > 0 else None)
    append_flag(argv, "--update-snapshots", ctx.attr.update_snapshots)
    append_flag_value(argv, "--rerun-each", str(ctx.attr.rerun_each) if ctx.attr.rerun_each > 0 else None)
    append_flag_value(argv, "--retry", str(ctx.attr.retry) if ctx.attr.retry > 0 else None)
    append_flag(argv, "--todo", ctx.attr.todo)
    append_flag(argv, "--only", ctx.attr.only)
    append_flag(argv, "--pass-with-no-tests", ctx.attr.pass_with_no_tests)
    append_flag(argv, "--concurrent", ctx.attr.concurrent)
    append_flag(argv, "--randomize", ctx.attr.randomize)
    append_flag_value(argv, "--seed", str(ctx.attr.seed) if ctx.attr.seed > 0 else None)
    append_flag_value(argv, "--bail", str(ctx.attr.bail) if ctx.attr.bail > 0 else None)
    append_flag_value(argv, "--max-concurrency", str(ctx.attr.max_concurrency) if ctx.attr.max_concurrency > 0 else None)
    append_raw_flags(argv, ctx.attr.test_flags)

    spec_file = write_launcher_spec(ctx, {
        "version": 1,
        "kind": "bun_test",
        "bun_short_path": runfiles_path(bun_bin),
        "primary_source_short_path": runfiles_path(primary_file),
        "package_json_short_path": "",
        "install_metadata_short_path": runfiles_path(workspace_info.install_metadata_file) if workspace_info.install_metadata_file else "",
        "install_repo_runfiles_path": workspace_info.install_repo_runfiles_path,
        "node_modules_roots": workspace_info.node_modules_roots,
        "package_dir_hint": workspace_info.package_dir_hint,
        "working_dir_mode": "workspace",
        "inherit_host_path": ctx.attr.inherit_host_path,
        "argv": argv,
        "args": ctx.attr.args,
        "passthrough_args": True,
        "tool_short_path": "",
        "restart_on": [],
        "watch_mode": "",
        "reporter": ctx.attr.reporter,
        "coverage": ctx.attr.coverage,
        "coverage_reporters": ctx.attr.coverage_reporters,
        "preload_short_paths": [runfiles_path(file) for file in ctx.files.preload],
        "env_file_short_paths": [runfiles_path(file) for file in ctx.files.env_files],
        "test_short_paths": [runfiles_path(file) for file in ctx.files.srcs],
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

_BUN_TEST_ATTRS = runtime_launcher_attrs()
_BUN_TEST_ATTRS.update({
    "srcs": attr.label_list(
        mandatory = True,
        allow_files = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs"],
        doc = "Test source files passed to `bun test`.",
    ),
    "node_modules": attr.label(
        doc = "Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, in runfiles.",
    ),
    "deps": attr.label_list(
        doc = "Library dependencies required by test sources.",
    ),
    "data": attr.label_list(
        allow_files = True,
        doc = "Additional runtime files needed by tests.",
    ),
    "preload": attr.label_list(
        allow_files = True,
        doc = "Modules to preload with `--preload` before running tests.",
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
    "install_mode": attr.string(
        default = "disable",
        values = ["disable", "auto", "fallback", "force"],
        doc = "Whether Bun may auto-install missing packages while testing.",
    ),
    "timeout_ms": attr.int(
        default = 0,
        doc = "Optional per-test timeout in milliseconds.",
    ),
    "update_snapshots": attr.bool(
        default = False,
        doc = "If true, updates Bun snapshot files.",
    ),
    "rerun_each": attr.int(
        default = 0,
        doc = "Optional number of times to rerun each test file.",
    ),
    "retry": attr.int(
        default = 0,
        doc = "Optional default retry count for all tests.",
    ),
    "todo": attr.bool(
        default = False,
        doc = "If true, includes tests marked with `test.todo()`.",
    ),
    "only": attr.bool(
        default = False,
        doc = "If true, runs only tests marked with `test.only()` or `describe.only()`.",
    ),
    "pass_with_no_tests": attr.bool(
        default = False,
        doc = "If true, exits successfully when no tests are found.",
    ),
    "concurrent": attr.bool(
        default = False,
        doc = "If true, treats all tests as concurrent tests.",
    ),
    "randomize": attr.bool(
        default = False,
        doc = "If true, runs tests in random order.",
    ),
    "seed": attr.int(
        default = 0,
        doc = "Optional randomization seed.",
    ),
    "bail": attr.int(
        default = 0,
        doc = "Optional failure count after which Bun exits the test run.",
    ),
    "reporter": attr.string(
        default = "console",
        values = ["console", "dots", "junit"],
        doc = "Test reporter format.",
    ),
    "max_concurrency": attr.int(
        default = 0,
        doc = "Optional maximum number of concurrent tests.",
    ),
    "coverage": attr.bool(
        default = False,
        doc = "If true, always enables Bun coverage output.",
    ),
    "coverage_reporters": attr.string_list(
        doc = "Repeated Bun coverage reporters such as `text` or `lcov`.",
    ),
    "test_flags": attr.string_list(
        doc = "Additional raw flags forwarded to `bun test` before the test source list.",
    ),
    "inherit_host_path": attr.bool(
        default = False,
        doc = "If true, appends the host PATH after staged node_modules/.bin entries at runtime.",
    ),
})

bun_test = rule(
    implementation = _bun_test_impl,
    doc = """Runs Bun tests as a Bazel test target.

Supports Bazel test filtering (`--test_filter`) and coverage integration. Tests
run with strict install-mode semantics and do not inherit the host PATH unless
explicitly requested.
""",
    attrs = _BUN_TEST_ATTRS,
    test = True,
    toolchains = ["//bun:toolchain_type"],
)
