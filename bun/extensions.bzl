load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//internal:bun_install.bzl", "bun_install_repository")
load(":version.bzl", "BUN_VERSION")

_BUN_ARCHIVES = {
    "bun_linux_x64": {
        "sha256": "f57bc0187e39623de716ba3a389fda5486b2d7be7131a980ba54dc7b733d2e08",
        "asset": "bun-linux-x64.zip",
        "binary": "bun-linux-x64/bun",
    },
    "bun_linux_aarch64": {
        "sha256": "fa5ecb25cafa8e8f5c87a0f833719d46dd0af0a86c7837d806531212d55636d3",
        "asset": "bun-linux-aarch64.zip",
        "binary": "bun-linux-aarch64/bun",
    },
    "bun_darwin_x64": {
        "sha256": "c1d90bf6140f20e572c473065dc6b37a4b036349b5e9e4133779cc642ad94323",
        "asset": "bun-darwin-x64.zip",
        "binary": "bun-darwin-x64/bun",
    },
    "bun_darwin_aarch64": {
        "sha256": "82034e87c9d9b4398ea619aee2eed5d2a68c8157e9a6ae2d1052d84d533ccd8d",
        "asset": "bun-darwin-aarch64.zip",
        "binary": "bun-darwin-aarch64/bun",
    },
    "bun_windows_x64": {
        "sha256": "7a77b3e245e2e26965c93089a4a1332e8a326d3364c89fae1d1fd99cdd3cd73d",
        "asset": "bun-windows-x64.zip",
        "binary": "bun-windows-x64/bun.exe",
    },
}

_BUN_GITHUB_RELEASE_URL_TEMPLATE = "https://github.com/oven-sh/bun/releases/download/bun-v{}/{}"


def _bun_repos_impl(_ctx):
    for name, metadata in _BUN_ARCHIVES.items():
        http_archive(
            name = name,
            urls = [_BUN_GITHUB_RELEASE_URL_TEMPLATE.format(BUN_VERSION, metadata["asset"])],
            sha256 = metadata["sha256"],
            build_file_content = """
exports_files(["{binary}"])

filegroup(
    name = "bun",
    srcs = ["{binary}"],
    visibility = ["//visibility:public"],
)
""".format(binary = metadata["binary"]),
        )


bun = module_extension(
    implementation = _bun_repos_impl,
)

_install = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "package_json": attr.string(mandatory = True),
        "bun_lockfile": attr.string(mandatory = True),
    },
)


def _bun_install_impl(ctx):
    for mod in ctx.modules:
        for install in mod.tags.install:
            bun_install_repository(
                name = install.name,
                package_json = install.package_json,
                bun_lockfile = install.bun_lockfile,
            )


bun_install = module_extension(
    implementation = _bun_install_impl,
    tag_classes = {"install": _install},
)
