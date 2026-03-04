load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
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


def _declare_bun_repo(name, asset, sha256, binary, version):
    if native.existing_rule(name):
        return

    http_archive(
        name = name,
        urls = [_BUN_GITHUB_RELEASE_URL_TEMPLATE.format(version, asset)],
        sha256 = sha256,
        build_file_content = """
exports_files(["{binary}"])

filegroup(
    name = "bun",
    srcs = ["{binary}"],
    visibility = ["//visibility:public"],
)
""".format(binary = binary),
    )


def bun_repositories(version = BUN_VERSION):
    for name, metadata in _BUN_ARCHIVES.items():
        _declare_bun_repo(
            name = name,
            asset = metadata["asset"],
            sha256 = metadata["sha256"],
            binary = metadata["binary"],
            version = version,
        )


def bun_register_toolchains(name = "bun", version = BUN_VERSION):
    bun_repositories(version = version)
    native.register_toolchains(
        "//bun:darwin_aarch64_toolchain",
        "//bun:darwin_x64_toolchain",
        "//bun:linux_aarch64_toolchain",
        "//bun:linux_x64_toolchain",
        "//bun:windows_x64_toolchain",
    )
