#!/usr/bin/env bash
set -euo pipefail

launcher="$1"
shift

python3 - "${launcher}" "$@" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
if path.suffix.lower() == ".cmd":
    path = pathlib.Path(str(path)[:-4])
spec = json.loads(pathlib.Path(f"{path}.launcher.json").read_text())
argv = spec["argv"]

for value in sys.argv[2:]:
    if value not in argv:
        raise SystemExit(f"missing {value!r} in argv {argv!r}")
PY
