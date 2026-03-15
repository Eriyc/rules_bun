"""Shared helpers for Bun build- and compile-style rules."""

load("//internal:bun_command.bzl", "add_flag", "add_flag_value", "add_flag_values", "add_install_mode", "add_raw_flags")
load("//internal:js_library.bzl", "collect_js_sources")

_STAGED_BUILD_RUNNER = """import { spawnSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";

const [, , manifestPath, ...buildArgs] = process.argv;
const execroot = process.cwd();
const stageDir = mkdtempSync(resolve(tmpdir(), "rules_bun_build-"));

function rewriteArgPath(flag, value) {
  return `${flag}=${resolve(execroot, value)}`;
}

try {
  for (const relpath of readFileSync(manifestPath, "utf8").split(/\\r?\\n/)) {
    if (!relpath) {
      continue;
    }
    const src = resolve(execroot, relpath);
    const dest = resolve(stageDir, relpath);
    mkdirSync(dirname(dest), { recursive: true });
    cpSync(src, dest, { dereference: true, force: true, recursive: true });
  }

  const forwardedArgs = [];
  for (let index = 0; index < buildArgs.length; index += 1) {
    const arg = buildArgs[index];
    if ((arg === "--outdir" || arg === "--outfile") && index + 1 < buildArgs.length) {
      forwardedArgs.push(arg, resolve(execroot, buildArgs[index + 1]));
      index += 1;
      continue;
    }
    if (arg.startsWith("--metafile=")) {
      forwardedArgs.push(rewriteArgPath("--metafile", arg.slice("--metafile=".length)));
      continue;
    }
    if (arg.startsWith("--metafile-md=")) {
      forwardedArgs.push(rewriteArgPath("--metafile-md", arg.slice("--metafile-md=".length)));
      continue;
    }
    forwardedArgs.push(arg);
  }

  const result = spawnSync(process.execPath, forwardedArgs, {
    cwd: stageDir,
    stdio: "inherit",
  });
  if (result.error) {
    throw result.error;
  }
  process.exit(typeof result.status === "number" ? result.status : 1);
} finally {
  rmSync(stageDir, { recursive: true, force: true });
}
"""

def sort_files_by_short_path(files):
    files_by_path = {}
    short_paths = []
    for file in files:
        files_by_path[file.short_path] = file
        short_paths.append(file.short_path)
    return [files_by_path[short_path] for short_path in sorted(short_paths)]

def validate_hermetic_install_mode(attr, rule_name):
    if getattr(attr, "install_mode", "disable") != "disable":
        fail("{} requires install_mode = \"disable\" for hermetic execution".format(rule_name))

def infer_entry_point_root(entries):
    if not entries:
        return None

    common_segments = entries[0].path.split("/")[:-1]
    for entry in entries[1:]:
        entry_segments = entry.path.split("/")[:-1]
        common_length = min(len(common_segments), len(entry_segments))
        idx = common_length
        for segment_idx in range(common_length):
            if common_segments[segment_idx] != entry_segments[segment_idx]:
                idx = segment_idx
                break
        common_segments = common_segments[:idx]

    if not common_segments:
        return "."

    return "/".join(common_segments)

def bun_build_transitive_inputs(ctx):
    transitive_inputs = []
    if getattr(ctx.attr, "node_modules", None):
        transitive_inputs.append(ctx.attr.node_modules[DefaultInfo].files)
    for dep in getattr(ctx.attr, "deps", []):
        transitive_inputs.append(collect_js_sources(dep))
    return transitive_inputs

def add_bun_build_common_flags(args, attr, metafile = None, metafile_md = None, root = None):
    build_root = root
    if build_root == None:
        build_root = getattr(attr, "root", None)

    add_install_mode(args, getattr(attr, "install_mode", "disable"))
    add_flag_value(args, "--target", getattr(attr, "target", None))
    add_flag_value(args, "--format", getattr(attr, "format", None))
    add_flag(args, "--production", getattr(attr, "production", False))
    add_flag(args, "--splitting", getattr(attr, "splitting", False))
    add_flag_value(args, "--root", build_root)

    sourcemap = getattr(attr, "sourcemap", None)
    if sourcemap == True:
        args.add("--sourcemap")
    elif sourcemap and sourcemap != "none":
        add_flag_value(args, "--sourcemap", sourcemap)

    add_flag_value(args, "--banner", getattr(attr, "banner", None))
    add_flag_value(args, "--footer", getattr(attr, "footer", None))
    add_flag_value(args, "--public-path", getattr(attr, "public_path", None))
    add_flag_value(args, "--packages", getattr(attr, "packages", None))
    add_flag_values(args, "--external", getattr(attr, "external", []))
    add_flag_value(args, "--entry-naming", getattr(attr, "entry_naming", None))
    add_flag_value(args, "--chunk-naming", getattr(attr, "chunk_naming", None))
    add_flag_value(args, "--asset-naming", getattr(attr, "asset_naming", None))
    add_flag(args, "--minify", getattr(attr, "minify", False))
    add_flag(args, "--minify-syntax", getattr(attr, "minify_syntax", False))
    add_flag(args, "--minify-whitespace", getattr(attr, "minify_whitespace", False))
    add_flag(args, "--minify-identifiers", getattr(attr, "minify_identifiers", False))
    add_flag(args, "--keep-names", getattr(attr, "keep_names", False))
    add_flag(args, "--css-chunking", getattr(attr, "css_chunking", False))
    add_flag_values(args, "--conditions", getattr(attr, "conditions", []))
    add_flag_value(args, "--env", getattr(attr, "env", None))
    add_flag_values(args, "--define", getattr(attr, "define", []))
    add_flag_values(args, "--drop", getattr(attr, "drop", []))
    add_flag_values(args, "--feature", getattr(attr, "feature", []))
    add_flag_values(args, "--loader", getattr(attr, "loader", []))
    add_flag_value(args, "--jsx-factory", getattr(attr, "jsx_factory", None))
    add_flag_value(args, "--jsx-fragment", getattr(attr, "jsx_fragment", None))
    add_flag_value(args, "--jsx-import-source", getattr(attr, "jsx_import_source", None))
    add_flag_value(args, "--jsx-runtime", getattr(attr, "jsx_runtime", None))
    add_flag(args, "--jsx-side-effects", getattr(attr, "jsx_side_effects", False))
    add_flag(args, "--react-fast-refresh", getattr(attr, "react_fast_refresh", False))
    add_flag(args, "--emit-dce-annotations", getattr(attr, "emit_dce_annotations", False))
    add_flag(args, "--no-bundle", getattr(attr, "no_bundle", False))
    if metafile:
        args.add("--metafile=%s" % metafile.path)
    if metafile_md:
        args.add("--metafile-md=%s" % metafile_md.path)
    add_raw_flags(args, getattr(attr, "build_flags", []))

def add_bun_compile_flags(args, attr, compile_executable = None):
    add_flag(args, "--compile", True)
    add_flag(args, "--bytecode", getattr(attr, "bytecode", False))
    add_flag_values(args, "--compile-exec-argv", getattr(attr, "compile_exec_argv", []))
    if getattr(attr, "compile_autoload_dotenv", True):
        args.add("--compile-autoload-dotenv")
    else:
        args.add("--no-compile-autoload-dotenv")
    if getattr(attr, "compile_autoload_bunfig", True):
        args.add("--compile-autoload-bunfig")
    else:
        args.add("--no-compile-autoload-bunfig")
    if getattr(attr, "compile_autoload_tsconfig", False):
        args.add("--compile-autoload-tsconfig")
    else:
        args.add("--no-compile-autoload-tsconfig")
    if getattr(attr, "compile_autoload_package_json", False):
        args.add("--compile-autoload-package-json")
    else:
        args.add("--no-compile-autoload-package-json")
    if compile_executable:
        add_flag_value(args, "--compile-executable-path", compile_executable.path)
    add_flag(args, "--windows-hide-console", getattr(attr, "windows_hide_console", False))
    add_flag_value(args, "--windows-icon", getattr(attr, "windows_icon", None))
    add_flag_value(args, "--windows-title", getattr(attr, "windows_title", None))
    add_flag_value(args, "--windows-publisher", getattr(attr, "windows_publisher", None))
    add_flag_value(args, "--windows-version", getattr(attr, "windows_version", None))
    add_flag_value(args, "--windows-description", getattr(attr, "windows_description", None))
    add_flag_value(args, "--windows-copyright", getattr(attr, "windows_copyright", None))

def declare_staged_bun_build_action(ctx, bun_bin, build_args, build_inputs, outputs, mnemonic, progress_message, name_suffix):
    sorted_inputs = sort_files_by_short_path(build_inputs.to_list())
    input_manifest = ctx.actions.declare_file(ctx.label.name + name_suffix + ".inputs")
    runner = ctx.actions.declare_file(ctx.label.name + name_suffix + "_runner.js")

    ctx.actions.write(
        output = input_manifest,
        content = "".join([file.path + "\n" for file in sorted_inputs]),
    )
    ctx.actions.write(
        output = runner,
        content = _STAGED_BUILD_RUNNER,
    )

    ctx.actions.run(
        executable = bun_bin,
        arguments = ["--bun", runner.path, input_manifest.path, build_args],
        inputs = depset(
            direct = [input_manifest, runner],
            transitive = [build_inputs],
        ),
        outputs = outputs,
        mnemonic = mnemonic,
        progress_message = progress_message,
    )
