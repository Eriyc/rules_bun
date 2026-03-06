#!/usr/bin/env bash
set -euo pipefail

binary="$1"
workdir="$(mktemp -d)"
log_file="${workdir}/vite.log"

cleanup() {
  if [[ -n ${server_pid:-} ]] && kill -0 "${server_pid}" 2>/dev/null; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi
  rm -rf "${workdir}"
}
trap cleanup EXIT

port="$(
  python3 - <<'PY'
import socket
sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
)"

"${binary}" --host 127.0.0.1 --port "${port}" --strictPort >"${log_file}" 2>&1 &
server_pid=$!

for _ in {1..60}; do
  if ! kill -0 "${server_pid}" 2>/dev/null; then
    cat "${log_file}" >&2
    echo "Vite server exited unexpectedly" >&2
    exit 1
  fi

  if curl --fail --silent "http://127.0.0.1:${port}/" | grep -Fq "Vite via bun_script"; then
    break
  fi

  sleep 0.5
done

if ! curl --fail --silent "http://127.0.0.1:${port}/" | grep -Fq "Vite via bun_script"; then
  cat "${log_file}" >&2
  echo "Timed out waiting for Vite index page" >&2
  exit 1
fi

if ! curl --fail --silent "http://127.0.0.1:${port}/main.js" | grep -Fq "Hello from Vite"; then
  cat "${log_file}" >&2
  echo "Expected Vite module output was not served" >&2
  exit 1
fi
