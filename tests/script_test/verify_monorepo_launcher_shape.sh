#!/usr/bin/env bash
set -euo pipefail

vite_launcher="$1"
paraglide_launcher="$2"

python3 - "${vite_launcher}" "${paraglide_launcher}" <<'PY'
import json
import pathlib
import sys

def read_spec(launcher: str):
    path = pathlib.Path(launcher)
    if path.suffix.lower() == ".cmd":
        path = pathlib.Path(str(path)[:-4])
    return json.loads(pathlib.Path(f"{path}.launcher.json").read_text())

vite_spec = read_spec(sys.argv[1])
paraglide_spec = read_spec(sys.argv[2])

assert all(not root.startswith("../") for root in vite_spec["node_modules_roots"]), vite_spec
assert "node_modules" in vite_spec["node_modules_roots"], vite_spec

assert all(not root.startswith("../") for root in paraglide_spec["node_modules_roots"]), paraglide_spec
assert "node_modules" in paraglide_spec["node_modules_roots"], paraglide_spec
assert "packages/i18n/node_modules" in paraglide_spec["node_modules_roots"], paraglide_spec
PY
