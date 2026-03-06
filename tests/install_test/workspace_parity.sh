#!/usr/bin/env bash
set -euo pipefail

bun_path="${1:-bun}"

if ! command -v bazel >/dev/null 2>&1; then
  echo "bazel is required on PATH" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
rules_bun_root="$(cd "${script_dir}/../.." && pwd -P)"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

fixture_dir="${workdir}/fixture"
plain_dir="${workdir}/plain"
bazel_dir="${workdir}/bazel"

mkdir -p "${fixture_dir}/packages/pkg-a" "${fixture_dir}/packages/pkg-b" "${fixture_dir}/packages/web"

cat >"${fixture_dir}/package.json" <<'JSON'
{
  "name": "workspace-parity-root",
  "private": true,
  "workspaces": ["packages/*"]
}
JSON

cat >"${fixture_dir}/packages/pkg-a/package.json" <<'JSON'
{
  "name": "@workspace/pkg-a",
  "version": "1.0.0",
  "main": "index.js"
}
JSON

cat >"${fixture_dir}/packages/pkg-a/index.js" <<'JS'
module.exports = { value: 42 };
JS

cat >"${fixture_dir}/packages/pkg-b/package.json" <<'JSON'
{
  "name": "@workspace/pkg-b",
  "version": "1.0.0",
  "dependencies": {
    "@workspace/pkg-a": "workspace:*",
    "is-number": "7.0.0"
  }
}
JSON

cat >"${fixture_dir}/packages/web/package.json" <<'JSON'
{
    "name": "@workspace/web",
    "private": true,
    "type": "module",
    "scripts": {
        "build": "vite build"
    },
    "devDependencies": {
        "vite": "5.4.14"
    }
}
JSON

cat >"${fixture_dir}/packages/web/index.html" <<'HTML'
<!doctype html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>Workspace Parity Web</title>
    </head>
    <body>
        <div id="app"></div>
        <script type="module" src="./main.js"></script>
    </body>
</html>
HTML

cat >"${fixture_dir}/packages/web/main.js" <<'JS'
import { value } from "./value.js";

const app = document.querySelector("#app");
if (app) {
    app.textContent = `value=${value}`;
}
JS

cat >"${fixture_dir}/packages/web/value.js" <<'JS'
export const value = 42;
JS

cat >"${fixture_dir}/packages/web/vite.config.js" <<'JS'
export default {
    resolve: {
        preserveSymlinks: true,
    },
    optimizeDeps: {
        esbuildOptions: {
            preserveSymlinks: true,
        },
    },
};
JS

"${bun_path}" install --cwd "${fixture_dir}" >/dev/null
rm -rf "${fixture_dir}/node_modules" "${fixture_dir}/packages/pkg-b/node_modules"

cp -R "${fixture_dir}" "${plain_dir}"
cp -R "${fixture_dir}" "${bazel_dir}"

"${bun_path}" install --cwd "${plain_dir}" --frozen-lockfile >/dev/null

cat >"${bazel_dir}/MODULE.bazel" <<EOF
module(
    name = "workspace_parity_test",
)

bazel_dep(name = "rules_bun", version = "0.2.2")
bazel_dep(name = "rules_shell", version = "0.6.1")

local_path_override(
    module_name = "rules_bun",
    path = "${rules_bun_root}",
)

bun_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun")
use_repo(
    bun_ext,
    "bun_darwin_aarch64",
    "bun_darwin_x64",
    "bun_linux_aarch64",
    "bun_linux_x64",
    "bun_windows_x64",
)

bun_install_ext = use_extension("@rules_bun//bun:extensions.bzl", "bun_install")
bun_install_ext.install(
    name = "node_modules",
    package_json = "//:package.json",
    bun_lockfile = "//:bun.lock",
)
use_repo(bun_install_ext, "node_modules")

register_toolchains(
    "@rules_bun//bun:darwin_aarch64_toolchain",
    "@rules_bun//bun:darwin_x64_toolchain",
    "@rules_bun//bun:linux_aarch64_toolchain",
    "@rules_bun//bun:linux_x64_toolchain",
    "@rules_bun//bun:windows_x64_toolchain",
)
EOF

cat >"${bazel_dir}/BUILD.bazel" <<'EOF'
load("@rules_bun//bun:defs.bzl", "bun_script")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

exports_files([
    "package.json",
    "bun.lock",
    "node_modules_smoke_test.sh",
])

bun_script(
    name = "web_build",
    script = "build",
    package_json = "packages/web/package.json",
    node_modules = "@node_modules//:node_modules",
    data = [
        "packages/web/index.html",
        "packages/web/main.js",
        "packages/web/value.js",
        "packages/web/vite.config.js",
    ],
)

sh_test(
        name = "node_modules_smoke_test",
        srcs = ["node_modules_smoke_test.sh"],
        data = ["@node_modules//:node_modules"],
)
EOF

cat >"${bazel_dir}/node_modules_smoke_test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

runfiles_dir="${RUNFILES_DIR:-$0.runfiles}"
if ! find "${runfiles_dir}" -path '*/node_modules/.bin/vite' -print -quit | grep -q .; then
    echo "vite binary not found in runfiles node_modules/.bin" >&2
    exit 1
fi
EOF

chmod +x "${bazel_dir}/node_modules_smoke_test.sh"

(
  cd "${bazel_dir}"
  bazel build @node_modules//:node_modules >/dev/null
  bazel test //:node_modules_smoke_test >/dev/null
  bazel run //:web_build -- --emptyOutDir >/dev/null
)

output_base="$(cd "${bazel_dir}" && bazel info output_base)"
bazel_repo_dir="$(find "${output_base}/external" -maxdepth 1 -type d -name '*+node_modules' | head -n 1)"

if [[ -z ${bazel_repo_dir} ]]; then
  echo "Could not locate generated Bazel node_modules repository" >&2
  exit 1
fi

bazel_node_modules="${bazel_repo_dir}/node_modules"
plain_node_modules="${plain_dir}/node_modules"

if [[ ! -d ${plain_node_modules} ]]; then
  echo "Plain Bun install did not produce node_modules" >&2
  exit 1
fi

if [[ ! -d ${bazel_node_modules} ]]; then
  echo "Bazel bun_install did not produce node_modules" >&2
  exit 1
fi

plain_layout_manifest="${workdir}/plain.layout.manifest"
bazel_layout_manifest="${workdir}/bazel.layout.manifest"

python3 - "${plain_dir}" >"${plain_layout_manifest}" <<'PY'
import hashlib
import os
import stat
import sys

root = sys.argv[1]

def include(rel):
    if rel == "node_modules" or rel.startswith("node_modules/"):
        return True
    if rel.startswith("packages/") and "/node_modules" in rel:
        return True
    return False

for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort()
    filenames.sort()
    rel_dir = os.path.relpath(dirpath, root)
    if rel_dir == ".":
        rel_dir = ""
    for name in dirnames + filenames:
        full = os.path.join(dirpath, name)
        rel = os.path.join(rel_dir, name) if rel_dir else name
        if not include(rel):
            continue
        st = os.lstat(full)
        mode = st.st_mode
        if stat.S_ISLNK(mode):
            print(f"L {rel} -> {os.readlink(full)}")
        elif stat.S_ISDIR(mode):
            print(f"D {rel}")
        elif stat.S_ISREG(mode):
            h = hashlib.sha256()
            with open(full, "rb") as f:
                while True:
                    chunk = f.read(1024 * 1024)
                    if not chunk:
                        break
                    h.update(chunk)
            print(f"F {rel} {h.hexdigest()}")
        else:
            print(f"O {rel} {mode}")
PY

python3 - "${bazel_repo_dir}" >"${bazel_layout_manifest}" <<'PY'
import hashlib
import os
import stat
import sys

root = sys.argv[1]

def include(rel):
    if rel == "node_modules" or rel.startswith("node_modules/"):
        return True
    if rel.startswith("packages/") and "/node_modules" in rel:
        return True
    return False

for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort()
    filenames.sort()
    rel_dir = os.path.relpath(dirpath, root)
    if rel_dir == ".":
        rel_dir = ""
    for name in dirnames + filenames:
        full = os.path.join(dirpath, name)
        rel = os.path.join(rel_dir, name) if rel_dir else name
        if not include(rel):
            continue
        st = os.lstat(full)
        mode = st.st_mode
        if stat.S_ISLNK(mode):
            print(f"L {rel} -> {os.readlink(full)}")
        elif stat.S_ISDIR(mode):
            print(f"D {rel}")
        elif stat.S_ISREG(mode):
            h = hashlib.sha256()
            with open(full, "rb") as f:
                while True:
                    chunk = f.read(1024 * 1024)
                    if not chunk:
                        break
                    h.update(chunk)
            print(f"F {rel} {h.hexdigest()}")
        else:
            print(f"O {rel} {mode}")
PY

if ! diff -u "${plain_layout_manifest}" "${bazel_layout_manifest}"; then
  echo "Workspace node_modules layout differs between plain bun install and Bazel bun_install" >&2
  exit 1
fi

plain_manifest="${workdir}/plain.manifest"
bazel_manifest="${workdir}/bazel.manifest"

python3 - "${plain_node_modules}" >"${plain_manifest}" <<'PY'
import hashlib
import os
import stat
import sys

root = sys.argv[1]

for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort()
    filenames.sort()
    rel_dir = os.path.relpath(dirpath, root)
    if rel_dir == ".":
        rel_dir = ""
    for name in dirnames + filenames:
        full = os.path.join(dirpath, name)
        rel = os.path.join(rel_dir, name) if rel_dir else name
        st = os.lstat(full)
        mode = st.st_mode
        if stat.S_ISLNK(mode):
            print(f"L {rel} -> {os.readlink(full)}")
        elif stat.S_ISDIR(mode):
            print(f"D {rel}")
        elif stat.S_ISREG(mode):
            h = hashlib.sha256()
            with open(full, "rb") as f:
                while True:
                    chunk = f.read(1024 * 1024)
                    if not chunk:
                        break
                    h.update(chunk)
            print(f"F {rel} {h.hexdigest()}")
        else:
            print(f"O {rel} {mode}")
PY

python3 - "${bazel_node_modules}" >"${bazel_manifest}" <<'PY'
import hashlib
import os
import stat
import sys

root = sys.argv[1]

for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort()
    filenames.sort()
    rel_dir = os.path.relpath(dirpath, root)
    if rel_dir == ".":
        rel_dir = ""
    for name in dirnames + filenames:
        full = os.path.join(dirpath, name)
        rel = os.path.join(rel_dir, name) if rel_dir else name
        st = os.lstat(full)
        mode = st.st_mode
        if stat.S_ISLNK(mode):
            print(f"L {rel} -> {os.readlink(full)}")
        elif stat.S_ISDIR(mode):
            print(f"D {rel}")
        elif stat.S_ISREG(mode):
            h = hashlib.sha256()
            with open(full, "rb") as f:
                while True:
                    chunk = f.read(1024 * 1024)
                    if not chunk:
                        break
                    h.update(chunk)
            print(f"F {rel} {h.hexdigest()}")
        else:
            print(f"O {rel} {mode}")
PY

if ! diff -u "${plain_manifest}" "${bazel_manifest}"; then
  echo "node_modules trees differ between plain bun install and Bazel bun_install" >&2
  exit 1
fi

rm -rf "${plain_dir}/packages/web/dist"
"${bun_path}" run --cwd "${plain_dir}/packages/web" build -- --emptyOutDir >/dev/null

(
  cd "${bazel_dir}"
  bazel run //:web_build -- --emptyOutDir >/dev/null
)

plain_dist_dir="${plain_dir}/packages/web/dist"
bazel_dist_dir="${bazel_dir}/bazel-bin/web_build.runfiles/_main/packages/web/dist"

if [[ ! -d ${plain_dist_dir} ]]; then
  echo "Plain Bun Vite build did not produce output" >&2
  exit 1
fi

if [[ ! -d ${bazel_dist_dir} ]]; then
  echo "Bazel Vite build did not produce output" >&2
  exit 1
fi

plain_build_manifest="${workdir}/plain.build.manifest"
bazel_build_manifest="${workdir}/bazel.build.manifest"

python3 - "${plain_dist_dir}" >"${plain_build_manifest}" <<'PY'
import hashlib
import os
import stat
import sys

root = sys.argv[1]

for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort()
    filenames.sort()
    rel_dir = os.path.relpath(dirpath, root)
    if rel_dir == ".":
        rel_dir = ""
    for name in dirnames + filenames:
        full = os.path.join(dirpath, name)
        rel = os.path.join(rel_dir, name) if rel_dir else name
        st = os.lstat(full)
        mode = st.st_mode
        if stat.S_ISLNK(mode):
            print(f"L {rel} -> {os.readlink(full)}")
        elif stat.S_ISDIR(mode):
            print(f"D {rel}")
        elif stat.S_ISREG(mode):
            h = hashlib.sha256()
            with open(full, "rb") as f:
                while True:
                    chunk = f.read(1024 * 1024)
                    if not chunk:
                        break
                    h.update(chunk)
            print(f"F {rel} {h.hexdigest()}")
        else:
            print(f"O {rel} {mode}")
PY

python3 - "${bazel_dist_dir}" >"${bazel_build_manifest}" <<'PY'
import hashlib
import os
import stat
import sys

root = sys.argv[1]

for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
    dirnames.sort()
    filenames.sort()
    rel_dir = os.path.relpath(dirpath, root)
    if rel_dir == ".":
        rel_dir = ""
    for name in dirnames + filenames:
        full = os.path.join(dirpath, name)
        rel = os.path.join(rel_dir, name) if rel_dir else name
        st = os.lstat(full)
        mode = st.st_mode
        if stat.S_ISLNK(mode):
            print(f"L {rel} -> {os.readlink(full)}")
        elif stat.S_ISDIR(mode):
            print(f"D {rel}")
        elif stat.S_ISREG(mode):
            h = hashlib.sha256()
            with open(full, "rb") as f:
                while True:
                    chunk = f.read(1024 * 1024)
                    if not chunk:
                        break
                    h.update(chunk)
            print(f"F {rel} {h.hexdigest()}")
        else:
            print(f"O {rel} {mode}")
PY

if ! diff -u "${plain_build_manifest}" "${bazel_build_manifest}"; then
  echo "Vite build outputs differ between plain Bun and Bazel bun_script" >&2
  exit 1
fi
