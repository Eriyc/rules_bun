#!/usr/bin/env bash
set -euo pipefail

python3 - "$@" <<'PY'
import pathlib
import sys

windows = sys.platform.startswith("win")

for launcher in sys.argv[1:]:
    suffix = pathlib.Path(launcher).suffix.lower()
    if windows:
        if suffix != ".cmd":
            raise SystemExit(f"expected .cmd launcher on Windows: {launcher}")
    elif suffix == ".sh":
        raise SystemExit(f"unexpected .sh launcher executable: {launcher}")
PY
