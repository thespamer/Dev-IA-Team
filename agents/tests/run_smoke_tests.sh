#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="$ROOT_DIR/agents"
PO_MEMORY_FILE="$AGENTS_DIR/pods/po/memory.md"
PO_MEMORY_BAK=""

cleanup() {
    if [ -n "$PO_MEMORY_BAK" ] && [ -f "$PO_MEMORY_BAK" ]; then
        cp "$PO_MEMORY_BAK" "$PO_MEMORY_FILE"
        rm -f "$PO_MEMORY_BAK"
    fi
    rm -rf "$AGENTS_DIR/.locks/po-memory.lock" 2>/dev/null || true
}

trap cleanup EXIT

echo "[smoke] Bash syntax check"
bash -n "$AGENTS_DIR/activate.sh"
bash -n "$AGENTS_DIR/update_memory.sh"
bash -n "$AGENTS_DIR/status.sh"
bash -n "$AGENTS_DIR/run_chain.sh"
bash -n "$AGENTS_DIR/archive_memory.sh"
bash -n "$AGENTS_DIR/doctor.sh"
bash -n "$AGENTS_DIR/tests/run_smoke_tests.sh"
bash -n "$AGENTS_DIR/tests/lint_text_consistency.sh"

echo "[smoke] Text consistency lint"
"$AGENTS_DIR/tests/lint_text_consistency.sh" >/dev/null

echo "[smoke] Doctor check"
"$AGENTS_DIR/doctor.sh" >/dev/null

echo "[smoke] Chain runner valid fixture"
printf '\n\n\n\n\n' | "$AGENTS_DIR/run_chain.sh" "$AGENTS_DIR/tests/fixtures/parser-valid.chain" >/dev/null

echo "[smoke] Chain runner invalid fixture (must fail)"
if printf '\n' | "$AGENTS_DIR/run_chain.sh" "$AGENTS_DIR/tests/fixtures/parser-invalid.chain" >/dev/null 2>&1; then
    echo "Expected parser-invalid.chain to fail, but it succeeded"
    exit 1
fi

echo "[smoke] Chain runner invalid command fixture (must fail)"
if printf '\n' | "$AGENTS_DIR/run_chain.sh" "$AGENTS_DIR/tests/fixtures/parser-invalid-command.chain" >/dev/null 2>&1; then
    echo "Expected parser-invalid-command.chain to fail, but it succeeded"
    exit 1
fi

echo "[smoke] update_memory strict validation (must fail invalid summary)"
before_hash="$(shasum -a 256 "$PO_MEMORY_FILE" | awk '{print $1}')"
if "$AGENTS_DIR/update_memory.sh" --strict-validate po "Resumo sem bloco valido" >/dev/null 2>&1; then
    echo "Expected --strict-validate to fail for invalid summary, but it succeeded"
    exit 1
fi
after_hash="$(shasum -a 256 "$PO_MEMORY_FILE" | awk '{print $1}')"
if [ "$before_hash" != "$after_hash" ]; then
    echo "Memory file changed after strict validation failure"
    exit 1
fi

echo "[smoke] lock contention on update_memory"
PO_MEMORY_BAK="$(mktemp)"
cp "$PO_MEMORY_FILE" "$PO_MEMORY_BAK"
mkdir -p "$AGENTS_DIR/.locks/po-memory.lock"
( sleep 0.5; rmdir "$AGENTS_DIR/.locks/po-memory.lock" 2>/dev/null || true ) &
"$AGENTS_DIR/update_memory.sh" --strict-validate po $'## MEMORY UPDATE\n- teste lock 1\n- teste lock 2\n- teste lock 3' >/dev/null

echo "[smoke] lock timeout on update_memory (must fail)"
mkdir -p "$AGENTS_DIR/.locks/po-memory.lock"
if LOCK_MAX_ATTEMPTS=3 LOCK_SLEEP_SECONDS=0.01 "$AGENTS_DIR/update_memory.sh" --strict-validate po $'## MEMORY UPDATE\n- timeout 1\n- timeout 2\n- timeout 3' >/dev/null 2>&1; then
    echo "Expected lock-timeout scenario to fail, but it succeeded"
    exit 1
fi
rmdir "$AGENTS_DIR/.locks/po-memory.lock" 2>/dev/null || true

echo "[smoke] OK"
