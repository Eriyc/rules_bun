"""Rules for Bun build outputs and standalone executables."""

load("//internal:bun_build_support.bzl", "add_bun_build_common_flags", "add_bun_compile_flags", "bun_build_transitive_inputs", "declare_staged_bun_build_action", "infer_entry_point_root", "sort_files_by_short_path", "validate_hermetic_install_mode")

def _bun_build_impl(ctx):
    validate_hermetic_install_mode(ctx.attr, "bun_build")

    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    entry_points = sort_files_by_short_path(ctx.files.entry_points)
    data_files = sort_files_by_short_path(ctx.files.data)
    output_dir = ctx.actions.declare_directory(ctx.label.name)
    metafile = None
    if ctx.attr.metafile:
        metafile = ctx.actions.declare_file(ctx.label.name + ".meta.json")
    metafile_md = None
    if ctx.attr.metafile_md:
        metafile_md = ctx.actions.declare_file(ctx.label.name + ".meta.md")
    build_root = ctx.attr.root
    if not build_root:
        build_root = infer_entry_point_root(entry_points)
    transitive_inputs = bun_build_transitive_inputs(ctx)
    build_inputs = depset(
        direct = entry_points + data_files,
        transitive = transitive_inputs,
    )

    build_args = ctx.actions.args()
    build_args.add("--bun")
    build_args.add("build")
    add_bun_build_common_flags(build_args, ctx.attr, metafile = metafile, metafile_md = metafile_md, root = build_root)
    build_args.add("--outdir")
    build_args.add(output_dir.path)
    build_args.add_all(entry_points)

    outputs = [output_dir]
    if metafile:
        outputs.append(metafile)
    if metafile_md:
        outputs.append(metafile_md)

    declare_staged_bun_build_action(
        ctx,
        bun_bin,
        build_args,
        build_inputs,
        outputs = outputs,
        mnemonic = "BunBuild",
        progress_message = "Building {} with Bun".format(ctx.label.name),
        name_suffix = "_build",
    )

    return [DefaultInfo(files = depset(outputs))]

def _bun_compile_impl(ctx):
    validate_hermetic_install_mode(ctx.attr, "bun_compile")

    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin
    output = ctx.actions.declare_file(ctx.label.name)
    compile_executable = ctx.file.compile_executable
    data_files = sort_files_by_short_path(ctx.files.data)

    args = ctx.actions.args()
    args.add("--bun")
    args.add("build")
    add_bun_build_common_flags(args, ctx.attr)
    add_bun_compile_flags(args, ctx.attr, compile_executable = compile_executable)
    args.add("--outfile")
    args.add(output.path)
    args.add(ctx.file.entry_point.path)

    direct_inputs = [ctx.file.entry_point] + data_files
    if compile_executable:
        direct_inputs.append(compile_executable)

    declare_staged_bun_build_action(
        ctx,
        bun_bin,
        args,
        depset(
            direct = direct_inputs,
            transitive = bun_build_transitive_inputs(ctx),
        ),
        outputs = [output],
        mnemonic = "BunCompile",
        progress_message = "Compiling {} with Bun".format(ctx.file.entry_point.short_path),
        name_suffix = "_compile",
    )

    return [
        DefaultInfo(
            executable = output,
            files = depset([output]),
        ),
    ]

_COMMON_BUILD_ATTRS = {
    "node_modules": attr.label(
        doc = "Optional label providing package files from a `node_modules` tree, typically produced by `bun_install`, for package resolution.",
    ),
    "deps": attr.label_list(
        doc = "Source/library dependencies that provide transitive inputs.",
    ),
    "data": attr.label_list(
        allow_files = True,
        doc = "Additional non-source files needed during building.",
    ),
    "install_mode": attr.string(
        default = "disable",
        values = ["disable", "auto", "fallback", "force"],
        doc = "Whether Bun may auto-install missing packages while executing the build. Hermetic build actions require `disable`; other values are rejected.",
    ),
    "target": attr.string(
        default = "browser",
        values = ["browser", "node", "bun"],
        doc = "Bun build target environment.",
    ),
    "format": attr.string(
        default = "esm",
        values = ["esm", "cjs", "iife"],
        doc = "Output module format.",
    ),
    "production": attr.bool(
        default = False,
        doc = "If true, sets `NODE_ENV=production` and enables Bun production mode.",
    ),
    "splitting": attr.bool(
        default = False,
        doc = "If true, enables code splitting.",
    ),
    "root": attr.string(
        doc = "Optional root directory for multiple entry points.",
    ),
    "sourcemap": attr.string(
        default = "none",
        values = ["none", "linked", "inline", "external"],
        doc = "Sourcemap emission mode.",
    ),
    "banner": attr.string(
        doc = "Optional bundle banner text.",
    ),
    "footer": attr.string(
        doc = "Optional bundle footer text.",
    ),
    "public_path": attr.string(
        doc = "Optional public path prefix for emitted imports.",
    ),
    "packages": attr.string(
        default = "bundle",
        values = ["bundle", "external"],
        doc = "Whether packages stay bundled or are treated as external.",
    ),
    "external": attr.string_list(
        doc = "Modules treated as externals (not bundled).",
    ),
    "entry_naming": attr.string(
        doc = "Optional entry naming template.",
    ),
    "chunk_naming": attr.string(
        doc = "Optional chunk naming template.",
    ),
    "asset_naming": attr.string(
        doc = "Optional asset naming template.",
    ),
    "minify": attr.bool(
        default = False,
        doc = "If true, enables all Bun minification passes.",
    ),
    "minify_syntax": attr.bool(
        default = False,
        doc = "If true, minifies syntax only.",
    ),
    "minify_whitespace": attr.bool(
        default = False,
        doc = "If true, minifies whitespace only.",
    ),
    "minify_identifiers": attr.bool(
        default = False,
        doc = "If true, minifies identifiers only.",
    ),
    "keep_names": attr.bool(
        default = False,
        doc = "If true, preserves function and class names when minifying.",
    ),
    "css_chunking": attr.bool(
        default = False,
        doc = "If true, Bun chunks CSS across multiple entry points.",
    ),
    "conditions": attr.string_list(
        doc = "Custom resolve conditions passed to Bun.",
    ),
    "env": attr.string(
        doc = "Inline environment variable behavior passed to `--env`.",
    ),
    "define": attr.string_list(
        doc = "Repeated `--define` values such as `process.env.NODE_ENV:\"production\"`.",
    ),
    "drop": attr.string_list(
        doc = "Repeated `--drop` values, for example `console`.",
    ),
    "feature": attr.string_list(
        doc = "Repeated `--feature` values for dead-code elimination.",
    ),
    "loader": attr.string_list(
        doc = "Repeated `--loader` values such as `.svg:file`.",
    ),
    "jsx_factory": attr.string(
        doc = "Optional JSX factory override.",
    ),
    "jsx_fragment": attr.string(
        doc = "Optional JSX fragment override.",
    ),
    "jsx_import_source": attr.string(
        doc = "Optional JSX import source override.",
    ),
    "jsx_runtime": attr.string(
        values = ["", "automatic", "classic"],
        default = "",
        doc = "Optional JSX runtime override.",
    ),
    "jsx_side_effects": attr.bool(
        default = False,
        doc = "If true, treats JSX as having side effects.",
    ),
    "react_fast_refresh": attr.bool(
        default = False,
        doc = "If true, enables Bun's React fast refresh transform.",
    ),
    "emit_dce_annotations": attr.bool(
        default = False,
        doc = "If true, re-emits DCE annotations in the bundle.",
    ),
    "no_bundle": attr.bool(
        default = False,
        doc = "If true, transpiles without bundling.",
    ),
    "build_flags": attr.string_list(
        doc = "Additional raw flags forwarded to `bun build`.",
    ),
}

bun_build = rule(
    implementation = _bun_build_impl,
    doc = """Builds one or more entry points with `bun build`.

The rule emits a directory artifact so Bun can materialize multi-file output
graphs such as HTML, CSS, assets, and split chunks. Optional metafile outputs
may be requested with `metafile` and `metafile_md`.
""",
    attrs = dict(_COMMON_BUILD_ATTRS, **{
        "entry_points": attr.label_list(
            mandatory = True,
            allow_files = True,
            doc = "Entry files to build, including JS/TS or HTML entry points.",
        ),
        "metafile": attr.bool(
            default = False,
            doc = "If true, emits Bun's JSON metafile alongside the output directory.",
        ),
        "metafile_md": attr.bool(
            default = False,
            doc = "If true, emits Bun's markdown metafile alongside the output directory.",
        ),
    }),
    toolchains = ["//bun:toolchain_type"],
)

bun_compile = rule(
    implementation = _bun_compile_impl,
    doc = """Compiles a Bun program into a standalone executable with `bun build --compile`.""",
    attrs = dict(_COMMON_BUILD_ATTRS, **{
        "target": attr.string(
            default = "bun",
            values = ["browser", "node", "bun"],
            doc = "Bun build target environment for the compiled executable.",
        ),
        "entry_point": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "Entry file to compile into an executable.",
        ),
        "bytecode": attr.bool(
            default = False,
            doc = "If true, enables Bun bytecode caching in the compiled executable.",
        ),
        "compile_exec_argv": attr.string_list(
            doc = "Repeated `--compile-exec-argv` values prepended to the executable's `execArgv`.",
        ),
        "compile_executable": attr.label(
            allow_single_file = True,
            doc = "Optional Bun executable used for cross-compilation via `--compile-executable-path`.",
        ),
        "compile_autoload_dotenv": attr.bool(
            default = True,
            doc = "Whether the compiled executable auto-loads `.env` files at runtime.",
        ),
        "compile_autoload_bunfig": attr.bool(
            default = True,
            doc = "Whether the compiled executable auto-loads `bunfig.toml` at runtime.",
        ),
        "compile_autoload_tsconfig": attr.bool(
            default = False,
            doc = "Whether the compiled executable auto-loads `tsconfig.json` at runtime.",
        ),
        "compile_autoload_package_json": attr.bool(
            default = False,
            doc = "Whether the compiled executable auto-loads `package.json` at runtime.",
        ),
        "windows_hide_console": attr.bool(
            default = False,
            doc = "When targeting Windows, hides the console window for GUI-style executables.",
        ),
        "windows_icon": attr.string(
            doc = "Optional Windows icon path passed directly to Bun.",
        ),
        "windows_title": attr.string(
            doc = "Optional Windows executable title.",
        ),
        "windows_publisher": attr.string(
            doc = "Optional Windows publisher metadata.",
        ),
        "windows_version": attr.string(
            doc = "Optional Windows version metadata.",
        ),
        "windows_description": attr.string(
            doc = "Optional Windows description metadata.",
        ),
        "windows_copyright": attr.string(
            doc = "Optional Windows copyright metadata.",
        ),
    }),
    executable = True,
    toolchains = ["//bun:toolchain_type"],
)
