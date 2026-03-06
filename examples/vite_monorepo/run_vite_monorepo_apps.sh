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

pick_port() {
  python3 - <<'PY'
import socket
sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
}

matches_expected_js() {
  local content="$1"
  local expected="$2"

  if [[ ${expected} == *"*"* ]]; then
    local regex
    regex="$(printf '%s' "${expected}" | sed -e 's/[][(){}.+?^$|\\]/\\&/g' -e 's/\*/.*/g')"
    printf '%s' "${content}" | grep -Eq "${regex}"
  else
    printf '%s' "${content}" | grep -Fq "${expected}"
  fi
}

verify_vite_app() {
  local binary="$1"
  local expected_title="$2"
  local expected_js="$3"
  local log_name="$4"
  local port
  local main_js

  port="$(pick_port)"
  log_file="${workdir}/${log_name}.log"

  "${binary}" --host 127.0.0.1 --port "${port}" --strictPort >"${log_file}" 2>&1 &
  server_pid=$!

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

  main_js="$(curl --fail --silent "http://127.0.0.1:${port}/main.js")"
  if ! matches_expected_js "${main_js}" "${expected_js}"; then
    cat "${log_file}" >&2
    echo "Expected Vite module output was not served for ${log_name}" >&2
    exit 1
  fi

  kill "${server_pid}" 2>/dev/null || true
  wait "${server_pid}" 2>/dev/null || true
  server_pid=""
}

verify_vite_app "${app_a_binary}" "Vite monorepo app A" "Hello from monorepo app A" "app-a"
verify_vite_app "${app_b_binary}" "Vite monorepo app B" "Hello from monorepo app B *" "app-b"
