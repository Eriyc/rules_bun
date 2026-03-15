#!/usr/bin/env bash
set -euo pipefail

package_json_launcher="$1"
package_dir_hint_launcher="$2"

python3 - "${package_json_launcher}" "${package_dir_hint_launcher}" <<'PY'
import json
import pathlib
import sys

def read_spec(launcher: str):
    path = pathlib.Path(launcher)
    if path.suffix.lower() == ".cmd":
        path = pathlib.Path(str(path)[:-4])
    return json.loads(pathlib.Path(f"{path}.launcher.json").read_text())

package_json_spec = read_spec(sys.argv[1])
package_dir_hint_spec = read_spec(sys.argv[2])

assert package_json_spec["package_json_short_path"].endswith("tests/js_compat_test/app/package.json"), package_json_spec
assert package_json_spec["package_dir_hint"] == ".", package_json_spec
assert package_json_spec["working_dir_mode"] == "package", package_json_spec

assert package_dir_hint_spec["package_json_short_path"] == "", package_dir_hint_spec
assert package_dir_hint_spec["package_dir_hint"] == "app", package_dir_hint_spec
assert package_dir_hint_spec["working_dir_mode"] == "package", package_dir_hint_spec
PY
