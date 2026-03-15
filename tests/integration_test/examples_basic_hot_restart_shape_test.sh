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

assert spec["kind"] == "bun_run", spec
assert spec["watch_mode"] == "hot", spec
assert "--no-clear-screen" in spec["argv"], spec
assert spec["restart_on"], spec
assert spec["restart_on"][0].endswith("examples/basic/README.md"), spec
PY
