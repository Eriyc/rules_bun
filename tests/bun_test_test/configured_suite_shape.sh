#!/usr/bin/env bash
set -euo pipefail

launcher="$1"
retry_launcher="$2"

python3 - "${launcher}" "${retry_launcher}" <<'PY'
import json
import pathlib
import sys

def read_spec(launcher: str):
    path = pathlib.Path(launcher)
    if path.suffix.lower() == ".cmd":
        path = pathlib.Path(str(path)[:-4])
    return json.loads(pathlib.Path(f"{path}.launcher.json").read_text())

launcher_spec = read_spec(sys.argv[1])
retry_spec = read_spec(sys.argv[2])

for value in [
    "--no-install",
    "--no-env-file",
    "--timeout",
    "--update-snapshots",
    "--rerun-each",
    "--concurrent",
    "--randomize",
    "--seed",
    "--bail",
    "--max-concurrency",
]:
    assert value in launcher_spec["argv"], (value, launcher_spec)

assert launcher_spec["preload_short_paths"], launcher_spec
assert launcher_spec["env_file_short_paths"], launcher_spec
assert launcher_spec["reporter"] == "junit", launcher_spec
assert launcher_spec["coverage"] is True, launcher_spec
assert launcher_spec["coverage_reporters"] == ["lcov"], launcher_spec
assert "--retry" in retry_spec["argv"], retry_spec
assert "3" in retry_spec["argv"], retry_spec
PY
