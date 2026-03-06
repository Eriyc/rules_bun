"""Repository-rule based bun_install implementation."""

_DEFAULT_INSTALL_INPUTS = [
    ".npmrc",
    "bunfig.json",
    "bunfig.toml",
]

def _normalize_path(path):
    normalized = path.replace("\\", "/")
    if normalized.endswith("/") and normalized != "/":
        normalized = normalized[:-1]
    return normalized

def _relative_to_root(root, child):
    normalized_root = _normalize_path(root)
    normalized_child = _normalize_path(child)

    if normalized_child == normalized_root:
        return ""

    prefix = normalized_root + "/"
    if not normalized_child.startswith(prefix):
        fail("bun_install: expected install input {} to be under {}".format(child, root))

    return normalized_child[len(prefix):]

def _segment_matches(name, pattern):
    if pattern == "*":
        return True

    if "*" not in pattern:
        return name == pattern

    parts = pattern.split("*")
    if len(parts) == 1:
        return name == pattern

    pos = 0
    anchored_start = not pattern.startswith("*")
    anchored_end = not pattern.endswith("*")

    for i, part in enumerate(parts):
        if not part:
            continue

        match_index = name.find(part, pos)
        if match_index < 0:
            return False

        if i == 0 and anchored_start and match_index != 0:
            return False

        pos = match_index + len(part)

    if anchored_end and parts[-1] and not name.endswith(parts[-1]):
        return False

    return True

def _walk_workspace_dirs(root, segments):
    matches = [root]

    for segment in segments:
        if segment == "**":
            fail("bun_install: `**` is not supported in workspace patterns; use explicit segments or `*`")

        next_matches = []
        for parent in matches:
            for child in parent.readdir():
                if child.is_dir and _segment_matches(child.basename, segment):
                    next_matches.append(child)

        matches = next_matches

    return matches

def _workspace_patterns(repository_ctx, package_json):
    manifest = json.decode(repository_ctx.read(package_json))
    workspaces = manifest.get("workspaces", [])

    if type(workspaces) == type({}):
        workspaces = workspaces.get("packages", [])

    if type(workspaces) != type([]):
        fail("bun_install: `workspaces` must be a list or an object with a `packages` list")

    patterns = []
    for pattern in workspaces:
        if type(pattern) != type(""):
            fail("bun_install: workspace pattern must be a string, got {}".format(type(pattern)))

        normalized = "/".join([segment for segment in pattern.split("/") if segment and segment != "."])
        if normalized:
            patterns.append(normalized)

    return patterns

def _materialize_workspace_packages(repository_ctx, package_json):
    package_root = package_json.dirname
    package_root_str = str(package_root)
    written = {}

    for pattern in _workspace_patterns(repository_ctx, package_json):
        segments = pattern.split("/")
        for workspace_dir in _walk_workspace_dirs(package_root, segments):
            workspace_package_json = repository_ctx.path(str(workspace_dir) + "/package.json")
            if not workspace_package_json.exists:
                continue

            workspace_dir_str = str(workspace_dir)
            if workspace_dir_str == package_root_str:
                continue

            relative_dir = _relative_to_root(package_root_str, workspace_dir_str)
            if relative_dir in written:
                continue

            repository_ctx.file(
                relative_dir + "/package.json",
                repository_ctx.read(workspace_package_json),
            )
            written[relative_dir] = True

def _materialize_install_inputs(repository_ctx, package_json):
    package_root = package_json.dirname
    package_root_str = str(package_root)
    written = {}

    for relative_path in _DEFAULT_INSTALL_INPUTS:
        source_path = repository_ctx.path(str(package_root) + "/" + relative_path)
        if source_path.exists and not source_path.is_dir:
            repository_ctx.file(relative_path, repository_ctx.read(source_path))
            written[relative_path] = True

    for install_input in repository_ctx.attr.install_inputs:
        source_path = repository_ctx.path(install_input)

        if not source_path.exists:
            fail("bun_install: install input not found: {}".format(install_input))

        if source_path.is_dir:
            fail("bun_install: install_inputs must be files under the package root: {}".format(install_input))

        relative_path = _relative_to_root(package_root_str, str(source_path))
        if not relative_path:
            fail("bun_install: install input must be a file under the package root: {}".format(install_input))

        if relative_path in written:
            continue

        repository_ctx.file(relative_path, repository_ctx.read(source_path))
        written[relative_path] = True

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
    lockfile_name = bun_lockfile.basename

    if lockfile_name not in ["bun.lock", "bun.lockb"]:
        lockfile_name = "bun.lock"

    repository_ctx.file("package.json", repository_ctx.read(package_json))
    repository_ctx.symlink(bun_lockfile, lockfile_name)
    _materialize_install_inputs(repository_ctx, package_json)
    _materialize_workspace_packages(repository_ctx, package_json)

    install_args = [str(bun_bin), "--bun", "install", "--frozen-lockfile", "--no-progress"]
    if repository_ctx.attr.isolated_home:
        result = repository_ctx.execute(
            install_args,
            timeout = 600,
            quiet = False,
            environment = {"HOME": str(repository_ctx.path("."))},
        )
    else:
        result = repository_ctx.execute(
            install_args,
            timeout = 600,
            quiet = False,
        )

    if result.return_code:
        fail("""bun_install failed running `bun --bun install --frozen-lockfile`.
stdout:
{}
stderr:
{}
""".format(result.stdout, result.stderr))

    repository_ctx.file(
        "BUILD.bazel",
        """filegroup(
    name = "node_modules",
    srcs = glob(["**/node_modules/**"], allow_empty = False),
    visibility = ["//visibility:public"],
)
""",
    )

bun_install_repository = repository_rule(
    implementation = _bun_install_repository_impl,
    attrs = {
        "package_json": attr.label(mandatory = True, allow_single_file = True),
        "bun_lockfile": attr.label(mandatory = True, allow_single_file = True),
        "install_inputs": attr.label_list(allow_files = True),
        "isolated_home": attr.bool(default = True),
        "bun_linux_x64": attr.label(default = "@bun_linux_x64//:bun-linux-x64/bun", allow_single_file = True),
        "bun_linux_aarch64": attr.label(default = "@bun_linux_aarch64//:bun-linux-aarch64/bun", allow_single_file = True),
        "bun_darwin_x64": attr.label(default = "@bun_darwin_x64//:bun-darwin-x64/bun", allow_single_file = True),
        "bun_darwin_aarch64": attr.label(default = "@bun_darwin_aarch64//:bun-darwin-aarch64/bun", allow_single_file = True),
        "bun_windows_x64": attr.label(default = "@bun_windows_x64//:bun-windows-x64/bun.exe", allow_single_file = True),
    },
)

def bun_install(name, package_json, bun_lockfile, install_inputs = [], isolated_home = True):
    """Create an external repository containing installed node_modules.

    Args:
      name: Repository name to create.
      package_json: Label to a package.json file.
      bun_lockfile: Label to a bun.lockb file.
            install_inputs: Optional additional files under the package root to copy
                into the install context, such as patch files or auth/config files.
            isolated_home: Whether to run Bun with HOME set to the generated
                repository root for a more isolated install context.

    Usage (WORKSPACE):
      bun_install(
          name = "node_modules",
          package_json = "//:package.json",
          bun_lockfile = "//:bun.lockb",
      )
    """

    bun_install_repository(
        name = name,
        package_json = package_json,
        bun_lockfile = bun_lockfile,
        install_inputs = install_inputs,
        isolated_home = isolated_home,
    )
