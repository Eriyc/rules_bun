"""Shared launcher spec and OS-native wrapper helpers for runtime rules."""

_RUNTIME_LAUNCHER = Label("//internal:runtime_launcher.js")
_WINDOWS_CONSTRAINT = Label("@platforms//os:windows")

_POSIX_WRAPPER_TEMPLATE = """#!/bin/sh
set -eu

self="$0"
runfiles_dir="${RUNFILES_DIR:-}"
manifest="${RUNFILES_MANIFEST_FILE:-}"

if [ -n "${runfiles_dir}" ] && [ -d "${runfiles_dir}" ]; then
  :
elif [ -n "${manifest}" ] && [ -f "${manifest}" ]; then
  :
elif [ -d "${self}.runfiles" ]; then
  runfiles_dir="${self}.runfiles"
elif [ -f "${self}.runfiles_manifest" ]; then
  manifest="${self}.runfiles_manifest"
elif [ -f "${self}.exe.runfiles_manifest" ]; then
  manifest="${self}.exe.runfiles_manifest"
else
  echo "rules_bun: unable to locate runfiles for ${self}" >&2
  exit 1
fi

rlocation() {
  path="$1"
  if [ -n "${runfiles_dir}" ]; then
    printf '%s\\n' "${runfiles_dir}/${path}"
    return 0
  fi

  result=""
  while IFS= read -r line; do
    case "${line}" in
      "${path} "*)
        result="${line#${path} }"
        break
        ;;
    esac
  done < "${manifest}"
  if [ -z "${result}" ]; then
    echo "rules_bun: missing runfile ${path}" >&2
    exit 1
  fi
  printf '%s\\n' "${result}"
}

bun_bin="$(rlocation "__BUN_RUNFILES_PATH__")"
runner="$(rlocation "__RUNNER_RUNFILES_PATH__")"
spec="$(rlocation "__SPEC_RUNFILES_PATH__")"

export RULES_BUN_LAUNCHER_PATH="${self}"
if [ -n "${runfiles_dir}" ]; then
  export RULES_BUN_RUNFILES_DIR="${runfiles_dir}"
fi
if [ -n "${manifest}" ]; then
  export RULES_BUN_RUNFILES_MANIFEST="${manifest}"
fi

exec "${bun_bin}" --bun "${runner}" "${spec}" "$@"
"""

_CMD_WRAPPER_TEMPLATE = """@echo off
setlocal

set "SELF=%~f0"
set "RUNFILES_DIR_VALUE=%RUNFILES_DIR%"
set "RUNFILES_MANIFEST_VALUE=%RUNFILES_MANIFEST_FILE%"

if defined RUNFILES_DIR_VALUE if exist "%RUNFILES_DIR_VALUE%" goto have_runfiles
if defined RUNFILES_MANIFEST_VALUE if exist "%RUNFILES_MANIFEST_VALUE%" goto have_runfiles
if exist "%SELF%.runfiles" (
  set "RUNFILES_DIR_VALUE=%SELF%.runfiles"
  goto have_runfiles
)
if exist "%SELF%.runfiles_manifest" (
  set "RUNFILES_MANIFEST_VALUE=%SELF%.runfiles_manifest"
  goto have_runfiles
)
if exist "%~dpn0.runfiles_manifest" (
  set "RUNFILES_MANIFEST_VALUE=%~dpn0.runfiles_manifest"
  goto have_runfiles
)

echo rules_bun: unable to locate runfiles for "%SELF%" 1>&2
exit /b 1

:have_runfiles
call :rlocation "__BUN_RUNFILES_PATH__" BUN_BIN || exit /b 1
call :rlocation "__RUNNER_RUNFILES_PATH__" RUNNER || exit /b 1
call :rlocation "__SPEC_RUNFILES_PATH__" SPEC || exit /b 1

set "RULES_BUN_LAUNCHER_PATH=%SELF%"
if defined RUNFILES_DIR_VALUE (
  set "RULES_BUN_RUNFILES_DIR=%RUNFILES_DIR_VALUE%"
) else (
  set "RULES_BUN_RUNFILES_DIR="
)
if defined RUNFILES_MANIFEST_VALUE (
  set "RULES_BUN_RUNFILES_MANIFEST=%RUNFILES_MANIFEST_VALUE%"
) else (
  set "RULES_BUN_RUNFILES_MANIFEST="
)

"%BUN_BIN%" --bun "%RUNNER%" "%SPEC%" %*
exit /b %ERRORLEVEL%

:rlocation
set "LOOKUP=%~1"
set "OUTPUT_VAR=%~2"
if defined RUNFILES_DIR_VALUE (
  set "%OUTPUT_VAR%=%RUNFILES_DIR_VALUE%\\%LOOKUP:/=\\%"
  exit /b 0
)
for /f "tokens=1,* delims= " %%A in ('findstr /b /c:"%LOOKUP% " "%RUNFILES_MANIFEST_VALUE%"') do (
  set "%OUTPUT_VAR%=%%B"
  exit /b 0
)
echo rules_bun: missing runfile %LOOKUP% 1>&2
exit /b 1
"""

def runfiles_path(file):
    workspace_name = file.owner.workspace_name
    if workspace_name:
        return "{}/{}".format(workspace_name, file.short_path)
    return "_main/{}".format(file.short_path)

def runtime_launcher_attrs():
    return {
        "_runtime_launcher": attr.label(
            default = _RUNTIME_LAUNCHER,
            allow_single_file = True,
        ),
        "_windows_constraint": attr.label(
            default = _WINDOWS_CONSTRAINT,
        ),
    }

def is_windows_target(ctx):
    return ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])

def write_launcher_spec(ctx, spec):
    spec_file = ctx.actions.declare_file(ctx.label.name + ".launcher.json")
    ctx.actions.write(
        output = spec_file,
        content = json.encode(spec) + "\n",
    )
    return spec_file

def declare_runtime_wrapper(ctx, bun_bin, spec_file):
    runner = ctx.file._runtime_launcher
    wrapper = ctx.actions.declare_file(ctx.label.name + (".cmd" if is_windows_target(ctx) else ""))
    content = _CMD_WRAPPER_TEMPLATE if is_windows_target(ctx) else _POSIX_WRAPPER_TEMPLATE
    content = content.replace("__BUN_RUNFILES_PATH__", runfiles_path(bun_bin)).replace(
        "__RUNNER_RUNFILES_PATH__",
        runfiles_path(runner),
    ).replace(
        "__SPEC_RUNFILES_PATH__",
        runfiles_path(spec_file),
    )
    ctx.actions.write(
        output = wrapper,
        content = content,
        is_executable = True,
    )
    return struct(
        executable = wrapper,
        runner = runner,
    )
