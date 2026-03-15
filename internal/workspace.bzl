"""Shared Bun workspace metadata helpers."""

BunWorkspaceInfo = provider(
    doc = "Workspace/runtime metadata shared by Bun rules and adapters.",
    fields = {
        "install_metadata_file": "Optional install metadata file from bun_install.",
        "install_repo_runfiles_path": "Runfiles root for the node_modules repository when present.",
        "metadata_file": "Rule-local metadata file describing the staged workspace inputs.",
        "node_modules_files": "Depset of node_modules files from bun_install.",
        "node_modules_roots": "Sorted repo-relative node_modules roots available in runfiles.",
        "package_dir_hint": "Package-relative directory when known at analysis time.",
        "package_json": "Package manifest file when explicitly provided.",
        "primary_file": "Primary source file used to resolve the runtime package context.",
        "runtime_files": "Depset of runtime files required to stage the workspace.",
    },
)

def find_install_metadata_file(files):
    for file in files:
        if file.short_path.endswith("node_modules/.rules_bun/install.json"):
            return file
    return None

def _runfiles_workspace(file):
    workspace_name = file.owner.workspace_name
    if workspace_name:
        return workspace_name
    return "_main"

def _repo_relative_short_path(file):
    short_path = file.short_path.replace("\\", "/")
    workspace_name = _runfiles_workspace(file)
    external_prefix = "../{}/".format(workspace_name)
    if short_path.startswith(external_prefix):
        return short_path[len(external_prefix):]
    if short_path == "../{}".format(workspace_name):
        return "."
    return short_path

def resolve_node_modules_roots(files):
    roots = {}
    marker = "/node_modules/"
    for file in files:
        short_path = _repo_relative_short_path(file)
        if short_path == "node_modules" or short_path.startswith("node_modules/"):
            roots["node_modules"] = True

        marker_index = short_path.find(marker)
        if marker_index >= 0:
            roots[short_path[:marker_index + len("/node_modules")]] = True

    return sorted(roots.keys())

def create_bun_workspace_info(ctx, primary_file = None, package_json = None, package_dir_hint = ".", extra_files = None):
    direct_runtime_files = []
    if primary_file:
        direct_runtime_files.append(primary_file)
    if package_json and package_json != primary_file:
        direct_runtime_files.append(package_json)
    direct_runtime_files.extend(extra_files or [])

    node_modules_files = depset()
    install_metadata_file = None
    install_repo_runfiles_path = ""
    node_modules_roots = []
    if getattr(ctx.attr, "node_modules", None):
        node_modules_files = ctx.attr.node_modules[DefaultInfo].files
        node_modules_file_list = node_modules_files.to_list()
        install_metadata_file = find_install_metadata_file(node_modules_file_list)
        node_modules_roots = resolve_node_modules_roots(node_modules_file_list)
        if install_metadata_file:
            install_repo_runfiles_path = _runfiles_workspace(install_metadata_file)
        elif node_modules_file_list:
            install_repo_runfiles_path = _runfiles_workspace(node_modules_file_list[0])

    metadata_file = ctx.actions.declare_file(ctx.label.name + ".bun_workspace.json")
    ctx.actions.write(
        output = metadata_file,
        content = json.encode({
            "install_metadata": install_metadata_file.short_path if install_metadata_file else "",
            "install_repo_runfiles_path": install_repo_runfiles_path,
            "node_modules_roots": node_modules_roots,
            "package_dir_hint": package_dir_hint or ".",
            "package_json": package_json.short_path if package_json else "",
            "primary_file": primary_file.short_path if primary_file else "",
        }) + "\n",
    )
    direct_runtime_files.append(metadata_file)

    runtime_files = depset(
        direct = direct_runtime_files,
        transitive = [node_modules_files],
    )

    return BunWorkspaceInfo(
        install_metadata_file = install_metadata_file,
        install_repo_runfiles_path = install_repo_runfiles_path,
        metadata_file = metadata_file,
        node_modules_files = node_modules_files,
        node_modules_roots = node_modules_roots,
        package_dir_hint = package_dir_hint or ".",
        package_json = package_json,
        primary_file = primary_file,
        runtime_files = runtime_files,
    )

def workspace_runfiles(ctx, workspace_info, direct_files = None, transitive_files = None):
    return ctx.runfiles(
        files = direct_files or [],
        transitive_files = depset(
            transitive = [workspace_info.runtime_files] + (transitive_files or []),
        ),
    )
