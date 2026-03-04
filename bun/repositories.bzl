load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_BUN_VERSION = "1.1.38"

_BUN_ARCHIVES = {
    "bun_linux_x64": {
        "sha256": "a61da5357e28d4977fccd4851fed62ff4da3ea33853005c7dd93dac80bc53932",
        "asset": "bun-linux-x64.zip",
        "binary": "bun-linux-x64/bun",
    },
    "bun_linux_aarch64": {
        "sha256": "3b08fd0b31f745509e1fed9c690c80d1a32ef2b3c8d059583f643f696639bd21",
        "asset": "bun-linux-aarch64.zip",
        "binary": "bun-linux-aarch64/bun",
    },
    "bun_darwin_x64": {
        "sha256": "4e9814c9b2e64f9166ed8fc2a48f905a2195ea599b7ceda7ac821688520428a5",
        "asset": "bun-darwin-x64.zip",
        "binary": "bun-darwin-x64/bun",
    },
    "bun_darwin_aarch64": {
        "sha256": "bbc6fb0e7bb99e7e95001ba05105cf09d0b79c06941d9f6ee3d0b34dc1541590",
        "asset": "bun-darwin-aarch64.zip",
        "binary": "bun-darwin-aarch64/bun",
    },
    "bun_windows_x64": {
        "sha256": "52d6c588237c5a1071839dc20dc96f19ca9f8021b7757fa096d22927b0a44a8b",
        "asset": "bun-windows-x64.zip",
        "binary": "bun-windows-x64/bun.exe",
    },
}


def _declare_bun_repo(name, asset, sha256, binary, version):
    if native.existing_rule(name):
        return

    http_archive(
        name = name,
        urls = ["https://github.com/oven-sh/bun/releases/download/bun-v{}/{}".format(version, asset)],
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


def bun_repositories(version = _BUN_VERSION):
    for name, metadata in _BUN_ARCHIVES.items():
        _declare_bun_repo(
            name = name,
            asset = metadata["asset"],
            sha256 = metadata["sha256"],
            binary = metadata["binary"],
            version = version,
        )


def bun_register_toolchains(version = _BUN_VERSION):
    bun_repositories(version = version)
    native.register_toolchains(
        "//bun:darwin_aarch64_toolchain",
        "//bun:darwin_x64_toolchain",
        "//bun:linux_aarch64_toolchain",
        "//bun:linux_x64_toolchain",
        "//bun:windows_x64_toolchain",
    )
