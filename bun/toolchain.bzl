BunToolchainInfo = provider(fields = ["bun_bin", "version"])


def _bun_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            bun = BunToolchainInfo(
                bun_bin = ctx.executable.bun,
                version = ctx.attr.version,
            ),
        ),
    ]


bun_toolchain = rule(
    implementation = _bun_toolchain_impl,
    attrs = {
        "bun": attr.label(allow_single_file = True, executable = True, cfg = "exec"),
        "version": attr.string(mandatory = True),
    },
)
