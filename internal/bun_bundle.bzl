"""Rule for bundling JS/TS sources with Bun."""

load("//internal:js_library.bzl", "BunSourcesInfo")


def _output_name(target_name, entry):
    stem = entry.basename.rsplit(".", 1)[0]
    return "{}__{}.js".format(target_name, stem)


def _bun_bundle_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin

    transitive_inputs = []
    if ctx.attr.node_modules:
        transitive_inputs.append(ctx.attr.node_modules[DefaultInfo].files)
    for dep in ctx.attr.deps:
        if BunSourcesInfo in dep:
            transitive_inputs.append(dep[BunSourcesInfo].transitive_sources)
        else:
            transitive_inputs.append(dep[DefaultInfo].files)

    outputs = []
    for entry in ctx.files.entry_points:
        output = ctx.actions.declare_file(_output_name(ctx.label.name, entry))
        outputs.append(output)

        args = ctx.actions.args()
        args.add("--bun")
        args.add("build")
        args.add(entry.path)
        args.add("--outfile")
        args.add(output.path)
        args.add("--target")
        args.add(ctx.attr.target)
        args.add("--format")
        args.add(ctx.attr.format)
        if ctx.attr.minify:
            args.add("--minify")
        if ctx.attr.sourcemap:
            args.add("--sourcemap")
        for package in ctx.attr.external:
            args.add("--external")
            args.add(package)

        ctx.actions.run(
            executable = bun_bin,
            arguments = [args],
            inputs = depset(
                direct = [entry] + ctx.files.data,
                transitive = transitive_inputs,
            ),
            outputs = [output],
            mnemonic = "BunBundle",
            progress_message = "Bundling {} with Bun".format(entry.short_path),
        )

    return [DefaultInfo(files = depset(outputs))]


bun_bundle = rule(
    implementation = _bun_bundle_impl,
    doc = """Bundles one or more JS/TS entry points using Bun build.

Each entry point produces one output JavaScript artifact.
""",
    attrs = {
        "entry_points": attr.label_list(
            mandatory = True,
            allow_files = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs"],
            doc = "Entry files to bundle.",
        ),
        "node_modules": attr.label(
            doc = "Optional label providing Bun/npm package files for resolution.",
        ),
        "deps": attr.label_list(
            doc = "Source/library dependencies that provide transitive inputs.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional non-source files needed during bundling.",
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
        "minify": attr.bool(
            default = False,
            doc = "If true, minifies bundle output.",
        ),
        "sourcemap": attr.bool(
            default = False,
            doc = "If true, emits source maps.",
        ),
        "external": attr.string_list(
            doc = "Package names to treat as externals (not bundled).",
        ),
    },
    toolchains = ["//bun:toolchain_type"],
)
