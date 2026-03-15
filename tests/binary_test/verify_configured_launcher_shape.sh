#!/usr/bin/env bash
set -euo pipefail

launcher="$1"

python3 - "${launcher}" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if path.suffix.lower() == ".cmd":
    path = pathlib.Path(str(path)[:-4])
spec = json.loads(pathlib.Path(f"{path}.launcher.json").read_text())
argv = spec["argv"]

assert spec["install_metadata_short_path"].endswith("node_modules/.rules_bun/install.json"), spec
assert spec["inherit_host_path"] is True, spec
assert spec["node_modules_roots"], spec
assert all(not root.startswith("../") for root in spec["node_modules_roots"]), spec
for value in ["--smol", "--conditions", "browser", "development", "--install", "force", "--hot", "--console-depth", "4"]:
    assert value in argv, (value, spec)
PY
