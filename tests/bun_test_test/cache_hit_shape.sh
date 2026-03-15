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

assert spec["kind"] == "bun_test", spec
assert spec["argv"][:2] == ["--bun", "test"], spec
assert spec["test_short_paths"], spec
PY
