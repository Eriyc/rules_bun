"""Repository-rule based bun_install implementation."""

def _select_bun_binary(repository_ctx):
    os_name = repository_ctx.os.name.lower()
    arch = repository_ctx.os.arch.lower()

    if "linux" in os_name:
        if arch in ["aarch64", "arm64"]:
            return repository_ctx.path(repository_ctx.attr.bun_linux_aarch64)
        return repository_ctx.path(repository_ctx.attr.bun_linux_x64)

    if "mac" in os_name or "darwin" in os_name:
        if arch in ["aarch64", "arm64"]:
            return repository_ctx.path(repository_ctx.attr.bun_darwin_aarch64)
        return repository_ctx.path(repository_ctx.attr.bun_darwin_x64)

    if "windows" in os_name:
        return repository_ctx.path(repository_ctx.attr.bun_windows_x64)

    fail("Unsupported host platform: os={}, arch={}".format(repository_ctx.os.name, repository_ctx.os.arch))


def _bun_install_repository_impl(repository_ctx):
    package_json = repository_ctx.path(repository_ctx.attr.package_json)
    bun_lockfile = repository_ctx.path(repository_ctx.attr.bun_lockfile)

    if not package_json.exists:
        fail("bun_install: package_json not found: {}".format(repository_ctx.attr.package_json))

    if not bun_lockfile.exists:
        fail("bun_install: bun_lockfile not found: {}".format(repository_ctx.attr.bun_lockfile))

    bun_bin = _select_bun_binary(repository_ctx)

    repository_ctx.symlink(package_json, "package.json")
    repository_ctx.symlink(bun_lockfile, "bun.lockb")

    result = repository_ctx.execute(
        [str(bun_bin), "install", "--frozen-lockfile", "--no-progress"],
        timeout = 600,
        quiet = False,
        environment = {"HOME": str(repository_ctx.path("."))},
    )

    if result.return_code:
        fail("""bun_install failed running `bun install --frozen-lockfile`.
stdout:
{}
stderr:
{}
""".format(result.stdout, result.stderr))

    repository_ctx.file(
        "BUILD.bazel",
        """filegroup(
    name = "node_modules",
    srcs = glob(["node_modules/**"], allow_empty = False),
    visibility = ["//visibility:public"],
)
""",
    )


_bun_install_repository = repository_rule(
    implementation = _bun_install_repository_impl,
    attrs = {
        "package_json": attr.label(mandatory = True, allow_single_file = True),
        "bun_lockfile": attr.label(mandatory = True, allow_single_file = True),
        "bun_linux_x64": attr.label(default = "@bun_linux_x64//:bun", allow_single_file = True),
        "bun_linux_aarch64": attr.label(default = "@bun_linux_aarch64//:bun", allow_single_file = True),
        "bun_darwin_x64": attr.label(default = "@bun_darwin_x64//:bun", allow_single_file = True),
        "bun_darwin_aarch64": attr.label(default = "@bun_darwin_aarch64//:bun", allow_single_file = True),
        "bun_windows_x64": attr.label(default = "@bun_windows_x64//:bun", allow_single_file = True),
    },
)


def bun_install(name, package_json, bun_lockfile):
    """Create an external repository containing installed node_modules.

    Args:
      name: Repository name to create.
      package_json: Label to a package.json file.
      bun_lockfile: Label to a bun.lockb file.

    Usage (WORKSPACE):
      bun_install(
          name = "node_modules",
          package_json = "//:package.json",
          bun_lockfile = "//:bun.lockb",
      )
    """

    _bun_install_repository(
        name = name,
        package_json = package_json,
        bun_lockfile = bun_lockfile,
    )
