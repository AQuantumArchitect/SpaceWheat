#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
EXPORT_DIR="${1:-$PROJECT_DIR/releases/web-local}"
PORT="${WEB_QA_PORT:-8031}"
BASE_URL="http://127.0.0.1:${PORT}"
TMP_DIR="$(mktemp -d /tmp/spacewheat-web-qa.XXXXXX)"
SERVER_LOG="$TMP_DIR/server.log"

cleanup() {
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill "$SERVER_PID" >/dev/null 2>&1 || true
        wait "$SERVER_PID" >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[[ -d "$EXPORT_DIR" ]] || fail "export dir not found: $EXPORT_DIR"

required_files=(
    index.html
    index.js
    index.pck
    index.wasm
    index.side.wasm
    index.service.worker.js
)

for file in "${required_files[@]}"; do
    [[ -f "$EXPORT_DIR/$file" ]] || fail "missing required file: $file"
done

python3 "$PROJECT_DIR/scripts/serve-web-local.py" "$EXPORT_DIR" --port "$PORT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 40); do
    if curl -fsS "$BASE_URL/index.html" >/dev/null 2>&1; then
        break
    fi
    sleep 0.25
done

curl -fsS "$BASE_URL/index.html" >/dev/null 2>&1 || fail "local QA server did not come up"

header_dump() {
    curl -fsSI "$1"
}

assert_header() {
    local url="$1"
    local name="$2"
    local expected="$3"
    local headers
    headers="$(header_dump "$url")"
    headers="$(printf '%s' "$headers" | tr -d '\r')"
    if ! grep -iq "^${name}: ${expected}$" <<<"$headers"; then
        echo "$headers" >&2
        fail "missing header ${name}: ${expected} on ${url}"
    fi
}

assert_header "$BASE_URL/index.html" "Cross-Origin-Embedder-Policy" "require-corp"
assert_header "$BASE_URL/index.html" "Cross-Origin-Opener-Policy" "same-origin"
assert_header "$BASE_URL/index.side.wasm" "Cross-Origin-Embedder-Policy" "require-corp"
assert_header "$BASE_URL/index.side.wasm" "Cross-Origin-Opener-Policy" "same-origin"
assert_header "$BASE_URL/index.wasm" "Cross-Origin-Embedder-Policy" "require-corp"
assert_header "$BASE_URL/index.wasm" "Cross-Origin-Opener-Policy" "same-origin"

python3 - <<'PY' "$EXPORT_DIR"
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
html = (root / "index.html").read_text()
js = (root / "index.js").read_text()
files = {p.name: p.stat().st_size for p in root.iterdir() if p.is_file()}

report = {
    "export_dir": str(root),
    "total_bytes": sum(files.values()),
    "files": files,
    "has_side_wasm_loader": ".side.wasm" in js,
    "has_service_worker": "serviceWorker" in html,
    "has_reload_after_sw_install": "window.location.reload()" in html,
    "ensures_cross_origin_isolation": 'ensureCrossOriginIsolationHeaders":true' in html,
    "checks_cross_origin_isolated": "crossOriginIsolated" in js,
    "checks_shared_array_buffer": "SharedArrayBuffer" in js,
}

print(json.dumps(report, indent=2, sort_keys=True))
PY
