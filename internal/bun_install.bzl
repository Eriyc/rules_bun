"""Repository-rule based bun_install implementation."""

_DEFAULT_INSTALL_INPUTS = [
    ".npmrc",
    "bunfig.json",
    "bunfig.toml",
]

_MANIFEST_DEP_FIELDS = [
    "dependencies",
    "devDependencies",
    "optionalDependencies",
    "peerDependencies",
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

def _validate_catalog_shape(field, value):
    if value == None:
        return

    if type(value) != type({}):
        fail("bun_install: `{}` must be an object".format(field))

    if field not in ["catalogs", "workspaces.catalogs"]:
        return

    for name, catalog in value.items():
        if type(name) != type(""):
            fail("bun_install: `catalogs` keys must be strings, got {}".format(type(name)))
        if type(catalog) != type({}):
            fail("bun_install: `catalogs.{}` must be an object".format(name))

def _copy_json_value(value):
    return json.decode(json.encode(value))

def _package_target_name(package_name):
    sanitized = package_name
    sanitized = sanitized.replace("@", "at_")
    sanitized = sanitized.replace("/", "_")
    sanitized = sanitized.replace("-", "_")
    sanitized = sanitized.replace(".", "_")
    sanitized = sanitized.replace("__", "_").replace("__", "_").replace("__", "_")
    sanitized = sanitized.strip("_")
    if not sanitized:
        sanitized = "package"
    return "npm__" + sanitized

def _manifest_dependency_names(manifest):
    names = {}
    for field in _MANIFEST_DEP_FIELDS:
        dependencies = manifest.get(field)
        if dependencies == None:
            continue
        if type(dependencies) != type({}):
            fail("bun_install: `{}` must be an object when present".format(field))
        for name in dependencies.keys():
            names[name] = True
    return names

def _normalized_root_manifest(repository_ctx, package_json):
    manifest = json.decode(repository_ctx.read(package_json))
    workspaces = manifest.get("workspaces")

    for field in ["catalog", "catalogs"]:
        manifest_value = manifest.get(field)
        _validate_catalog_shape(field, manifest_value)

        if type(workspaces) != type({}):
            continue

        workspace_value = workspaces.get(field)
        _validate_catalog_shape("workspaces.{}".format(field), workspace_value)

        if workspace_value == None:
            continue

        if manifest_value == None:
            manifest[field] = _copy_json_value(workspace_value)
            continue

        if manifest_value != workspace_value:
            fail(
                "bun_install: `{}` conflicts with `workspaces.{}`; use one source of truth or keep both values identical".format(field, field),
            )

    return json.encode(manifest)

def _materialize_workspace_packages(repository_ctx, package_json):
    package_root = package_json.dirname
    package_root_str = str(package_root)
    written = {}
    workspace_packages = {}

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
            manifest = json.decode(repository_ctx.read(workspace_package_json))
            package_name = manifest.get("name")
            workspace_packages[relative_dir] = package_name if type(package_name) == type("") else ""

    package_dirs = sorted(workspace_packages.keys())
    package_names_by_dir = {}
    for package_dir in package_dirs:
        package_name = workspace_packages[package_dir]
        if package_name:
            package_names_by_dir[package_dir] = package_name
    return struct(
        package_dirs = package_dirs,
        package_names_by_dir = package_names_by_dir,
        package_names = [workspace_packages[package_dir] for package_dir in package_dirs if workspace_packages[package_dir]],
    )

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

def _render_package_targets_file(package_names):
    lines = ["NPM_PACKAGE_TARGETS = {"]
    for package_name in package_names:
        lines.append('    "{}": "{}",'.format(package_name, _package_target_name(package_name)))
    lines.extend([
        "}",
        "",
    ])
    return "\n".join(lines)

def _render_repo_defs_bzl(repo_name):
    return """load(":packages.bzl", "NPM_PACKAGE_TARGETS")

def package_target_name(package_name):
    return NPM_PACKAGE_TARGETS.get(package_name)

def npm_link_all_packages(name = "node_modules", imported_links = []):
    if not native.existing_rule(name):
        native.alias(
            name = name,
            actual = "@{repo_name}//:node_modules",
        )

    requested = {{}}
    for package_name in imported_links:
        requested[package_name] = True

    for package_name, target_name in NPM_PACKAGE_TARGETS.items():
        if imported_links and package_name not in requested:
            continue
        if native.existing_rule(target_name):
            continue
        native.alias(
            name = target_name,
            actual = "@{repo_name}//:%s" % target_name,
        )
""".format(repo_name = repo_name)

def _render_repo_build(package_names):
    lines = [
        'exports_files(["defs.bzl", "packages.bzl"])',
        "",
        "filegroup(",
        '    name = "node_modules",',
        '    srcs = glob(["**/node_modules/**"], allow_empty = False),',
        '    visibility = ["//visibility:public"],',
        ")",
        "",
    ]

    for package_name in package_names:
        lines.extend([
            "filegroup(",
            '    name = "{}",'.format(_package_target_name(package_name)),
            '    srcs = glob(["node_modules/{}/**"], allow_empty = True),'.format(package_name),
            '    visibility = ["//visibility:public"],',
            ")",
            "",
        ])

    return "\n".join(lines)

def _bun_install_repository_impl(repository_ctx):
    package_json = repository_ctx.path(repository_ctx.attr.package_json)
    bun_lockfile = repository_ctx.path(repository_ctx.attr.bun_lockfile)

    if not package_json.exists:
        fail("bun_install: package_json not found: {}".format(repository_ctx.attr.package_json))

    if not bun_lockfile.exists:
        fail("bun_install: bun_lockfile not found: {}".format(repository_ctx.attr.bun_lockfile))

    bun_bin = _select_bun_binary(repository_ctx)
    lockfile_name = bun_lockfile.basename
    root_manifest = json.decode(repository_ctx.read(package_json))

    if lockfile_name not in ["bun.lock", "bun.lockb"]:
        lockfile_name = "bun.lock"

    repository_ctx.file("package.json", _normalized_root_manifest(repository_ctx, package_json))
    repository_ctx.symlink(bun_lockfile, lockfile_name)
    _materialize_install_inputs(repository_ctx, package_json)
    workspace_packages = _materialize_workspace_packages(repository_ctx, package_json)

    install_args = [str(bun_bin), "--bun", "install", "--frozen-lockfile", "--no-progress"]
    if repository_ctx.attr.production:
        install_args.append("--production")
    for omit in repository_ctx.attr.omit:
        install_args.extend(["--omit", omit])
    if repository_ctx.attr.linker:
        install_args.extend(["--linker", repository_ctx.attr.linker])
    if repository_ctx.attr.backend:
        install_args.extend(["--backend", repository_ctx.attr.backend])
    if repository_ctx.attr.ignore_scripts:
        install_args.append("--ignore-scripts")
    install_args.extend(repository_ctx.attr.install_flags)
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
        "node_modules/.rules_bun/install.json",
        json.encode({
            "bun_lockfile": lockfile_name,
            "install_root_rel_dir": ".",
            "package_json": "package.json",
            "workspace_package_dirs": workspace_packages.package_dirs,
            "workspace_package_names_by_dir": workspace_packages.package_names_by_dir,
        }) + "\n",
    )

    package_names = {}
    for package_name in _manifest_dependency_names(root_manifest).keys():
        package_names[package_name] = True
    for package_name in workspace_packages.package_names:
        package_names[package_name] = True

    sorted_package_names = sorted(package_names.keys())
    visible_repo_name = repository_ctx.attr.visible_repo_name or repository_ctx.name
    repository_ctx.file("packages.bzl", _render_package_targets_file(sorted_package_names))
    repository_ctx.file("defs.bzl", _render_repo_defs_bzl(visible_repo_name))
    repository_ctx.file("BUILD.bazel", _render_repo_build(sorted_package_names))

bun_install_repository = repository_rule(
    implementation = _bun_install_repository_impl,
    attrs = {
        "package_json": attr.label(mandatory = True, allow_single_file = True),
        "bun_lockfile": attr.label(mandatory = True, allow_single_file = True),
        "install_inputs": attr.label_list(allow_files = True),
        "isolated_home": attr.bool(default = True),
        "production": attr.bool(default = False),
        "omit": attr.string_list(),
        "linker": attr.string(),
        "backend": attr.string(),
        "ignore_scripts": attr.bool(default = True),
        "install_flags": attr.string_list(),
        "visible_repo_name": attr.string(),
        "bun_linux_x64": attr.label(default = "@bun_linux_x64//:bun-linux-x64/bun", allow_single_file = True),
        "bun_linux_aarch64": attr.label(default = "@bun_linux_aarch64//:bun-linux-aarch64/bun", allow_single_file = True),
        "bun_darwin_x64": attr.label(default = "@bun_darwin_x64//:bun-darwin-x64/bun", allow_single_file = True),
        "bun_darwin_aarch64": attr.label(default = "@bun_darwin_aarch64//:bun-darwin-aarch64/bun", allow_single_file = True),
        "bun_windows_x64": attr.label(default = "@bun_windows_x64//:bun-windows-x64/bun.exe", allow_single_file = True),
    },
)

def bun_install(
        name,
        package_json,
        bun_lockfile,
        install_inputs = [],
        isolated_home = True,
        production = False,
        omit = [],
        linker = "",
        backend = "",
        ignore_scripts = True,
        install_flags = []):
    """Create an external repository containing installed node_modules.

    Args:
      name: Repository name to create.
      package_json: Label to a package.json file.
      bun_lockfile: Label to a bun.lockb file.
            install_inputs: Optional additional files under the package root to copy
                into the install context, such as patch files or auth/config files.
            isolated_home: Whether to run Bun with HOME set to the generated
                repository root for a more isolated install context.
            production: Whether to omit devDependencies during install.
            omit: Optional Bun dependency groups to omit, such as `dev` or `peer`.
            linker: Optional Bun linker strategy, such as `isolated` or `hoisted`.
            backend: Optional Bun install backend, such as `hardlink` or `copyfile`.
            ignore_scripts: Whether to skip lifecycle scripts in the project manifest.
            install_flags: Additional raw flags forwarded to `bun install`.

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
        production = production,
        omit = omit,
        linker = linker,
        backend = backend,
        ignore_scripts = ignore_scripts,
        install_flags = install_flags,
        visible_repo_name = name,
    )
