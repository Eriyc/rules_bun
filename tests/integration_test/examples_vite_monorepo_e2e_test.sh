#!/usr/bin/env bash
set -euo pipefail

app_a_binary="$1"
app_b_binary="$2"
workdir="$(mktemp -d)"

server_pid=""
log_file=""

cleanup() {
  if [[ -n ${server_pid} ]] && kill -0 "${server_pid}" 2>/dev/null; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi
  rm -rf "${workdir}"
}
trap cleanup EXIT

start_launcher() {
  local launcher="$1"
  local log_target="$2"
  shift 2
  if [[ ${launcher} == *.cmd ]]; then
    cmd.exe /c call "${launcher}" "$@" >"${log_target}" 2>&1 &
  else
    "${launcher}" "$@" >"${log_target}" 2>&1 &
  fi
  server_pid=$!
}

pick_port() {
  python3 - <<'PY'
import socket
sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
}

verify_vite_app() {
  local binary="$1"
  local expected_title="$2"
  local expected_js="$3"
  local log_name="$4"
  local port

  port="$(pick_port)"
  log_file="${workdir}/${log_name}.log"

  start_launcher "${binary}" "${log_file}" --host 127.0.0.1 --port "${port}" --strictPort

  for _ in {1..60}; do
    if ! kill -0 "${server_pid}" 2>/dev/null; then
      cat "${log_file}" >&2
      echo "Vite server exited unexpectedly for ${log_name}" >&2
      exit 1
    fi

    if curl --fail --silent "http://127.0.0.1:${port}/" | grep -Fq "${expected_title}"; then
      break
    fi

    sleep 0.5
  done

  if ! curl --fail --silent "http://127.0.0.1:${port}/" | grep -Fq "${expected_title}"; then
    cat "${log_file}" >&2
    echo "Timed out waiting for Vite index page for ${log_name}" >&2
    exit 1
  fi

  if ! curl --fail --silent "http://127.0.0.1:${port}/main.js" | grep -Fq "${expected_js}"; then
    cat "${log_file}" >&2
    echo "Expected Vite module output was not served for ${log_name}" >&2
    exit 1
  fi

  kill "${server_pid}" 2>/dev/null || true
  wait "${server_pid}" 2>/dev/null || true
  server_pid=""
}

verify_vite_app "${app_a_binary}" "Vite monorepo app A" "Hello from monorepo app A" "app-a"
verify_vite_app "${app_b_binary}" "Vite monorepo app B" "Hello from monorepo app B" "app-b"
