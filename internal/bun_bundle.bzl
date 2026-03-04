"""Rule for bundling JS/TS sources with Bun."""


def _output_name(target_name, entry):
    stem = entry.basename.rsplit(".", 1)[0]
    return "{}__{}.js".format(target_name, stem)


def _bun_bundle_impl(ctx):
    toolchain = ctx.toolchains["//bun:toolchain_type"]
    bun_bin = toolchain.bun.bun_bin

    transitive_inputs = []
    if ctx.attr.node_modules:
        transitive_inputs.append(ctx.attr.node_modules[DefaultInfo].files)

    outputs = []
    for entry in ctx.files.entry_points:
        output = ctx.actions.declare_file(_output_name(ctx.label.name, entry))
        outputs.append(output)

        args = ctx.actions.args()
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
    attrs = {
        "entry_points": attr.label_list(
            mandatory = True,
            allow_files = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs"],
        ),
        "node_modules": attr.label(),
        "data": attr.label_list(allow_files = True),
        "target": attr.string(
            default = "browser",
            values = ["browser", "node", "bun"],
        ),
        "format": attr.string(
            default = "esm",
            values = ["esm", "cjs", "iife"],
        ),
        "minify": attr.bool(default = False),
        "sourcemap": attr.bool(default = False),
        "external": attr.string_list(),
    },
    toolchains = ["//bun:toolchain_type"],
)
