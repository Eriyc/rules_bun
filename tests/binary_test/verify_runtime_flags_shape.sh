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

assert "--no-install" in spec["argv"], spec
assert spec["inherit_host_path"] is False, spec
assert spec["preload_short_paths"] and spec["preload_short_paths"][0].endswith("tests/binary_test/preload.ts"), spec
assert spec["env_file_short_paths"] and spec["env_file_short_paths"][0].endswith("tests/binary_test/runtime.env"), spec
PY
