"""Shared Bun CLI flag builders for rules and launchers."""

def shell_quote(value):
    return "'" + str(value).replace("'", "'\"'\"'") + "'"

def _runfiles_workspace(file):
    workspace_name = file.owner.workspace_name
    if workspace_name:
        return workspace_name
    return "_main"

def runfiles_path_expr(file):
    return '"${runfiles_dir}/%s/%s"' % (_runfiles_workspace(file), file.short_path)

def render_shell_array(name, values):
    rendered = [shell_quote(value) for value in values]
    return "%s=(%s)" % (name, " ".join(rendered))

def append_shell_arg(lines, name, value):
    lines.append("%s+=(%s)" % (name, shell_quote(value)))

def append_shell_expr(lines, name, expr):
    lines.append("%s+=(%s)" % (name, expr))

def append_shell_flag(lines, name, flag, enabled):
    if enabled:
        append_shell_arg(lines, name, flag)

def append_shell_flag_value(lines, name, flag, value):
    if value == None:
        return
    if type(value) == type("") and not value:
        return
    append_shell_arg(lines, name, flag)
    append_shell_arg(lines, name, value)

def append_shell_flag_values(lines, name, flag, values):
    for value in values:
        append_shell_flag_value(lines, name, flag, value)

def append_shell_flag_files(lines, name, flag, files):
    for file in files:
        append_shell_arg(lines, name, flag)
        append_shell_expr(lines, name, runfiles_path_expr(file))

def append_shell_raw_flags(lines, name, values):
    for value in values:
        append_shell_arg(lines, name, value)

def append_shell_install_mode(lines, name, install_mode):
    if install_mode == "disable":
        append_shell_arg(lines, name, "--no-install")
    elif install_mode in ["fallback", "force"]:
        append_shell_flag_value(lines, name, "--install", install_mode)

def add_flag(args, flag, enabled):
    if enabled:
        args.add(flag)

def add_flag_value(args, flag, value):
    if value == None:
        return
    if type(value) == type("") and not value:
        return
    args.add(flag)
    args.add(value)

def add_flag_values(args, flag, values):
    for value in values:
        add_flag_value(args, flag, value)

def add_flag_files(args, flag, files):
    for file in files:
        args.add(flag)
        args.add(file.path)

def add_raw_flags(args, values):
    args.add_all(values)

def add_install_mode(args, install_mode):
    if install_mode == "disable":
        args.add("--no-install")
    elif install_mode in ["fallback", "force"]:
        add_flag_value(args, "--install", install_mode)

def append_arg(values, value):
    values.append(str(value))

def append_flag(values, flag, enabled):
    if enabled:
        append_arg(values, flag)

def append_flag_value(values, flag, value):
    if value == None:
        return
    if type(value) == type("") and not value:
        return
    append_arg(values, flag)
    append_arg(values, value)

def append_flag_values(values, flag, items):
    for item in items:
        append_flag_value(values, flag, item)

def append_raw_flags(values, items):
    for item in items:
        append_arg(values, item)

def append_install_mode(values, install_mode):
    if install_mode == "disable":
        append_arg(values, "--no-install")
    elif install_mode in ["fallback", "force"]:
        append_flag_value(values, "--install", install_mode)
