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

assert spec["reporter"] == "junit", spec
PY
