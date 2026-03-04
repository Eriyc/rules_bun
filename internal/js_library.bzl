"""Lightweight JS/TS source grouping rules."""

BunSourcesInfo = provider(fields = ["transitive_sources"])


def _bun_library_impl(ctx):
    transitive_sources = [
        dep[BunSourcesInfo].transitive_sources
        for dep in ctx.attr.deps
        if BunSourcesInfo in dep
    ]
    all_sources = depset(
        direct = ctx.files.srcs,
        transitive = transitive_sources,
    )
    return [
        BunSourcesInfo(transitive_sources = all_sources),
        DefaultInfo(files = all_sources),
    ]


js_library = rule(
    implementation = _bun_library_impl,
    doc = "Aggregates JavaScript sources and transitive Bun source dependencies.",
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".js", ".jsx", ".mjs", ".cjs"],
            doc = "JavaScript source files in this library.",
        ),
        "deps": attr.label_list(
            doc = "Other Bun source libraries to include transitively.",
        ),
    },
)

ts_library = rule(
    implementation = _bun_library_impl,
    doc = "Aggregates TypeScript sources and transitive Bun source dependencies.",
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".ts", ".tsx"],
            doc = "TypeScript source files in this library.",
        ),
        "deps": attr.label_list(
            doc = "Other Bun source libraries to include transitively.",
        ),
    },
)
