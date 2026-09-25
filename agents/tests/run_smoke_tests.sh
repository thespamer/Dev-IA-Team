#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="$ROOT_DIR/agents"
PO_LOG_DIR="$AGENTS_DIR/pods/po/memory"
CREATED_SHARDS=()

cleanup() {
    local shard
    for shard in "${CREATED_SHARDS[@]:-}"; do
        [ -n "$shard" ] && rm -f "$shard"
    done
    rm -rf "$AGENTS_DIR/.locks/po-memory.lock" 2>/dev/null || true
}

trap cleanup EXIT

# Shards criados durante o teste, para o cleanup remover no fim.
snapshot_new_shards() {
    local before="$1" after
    after="$(find "$PO_LOG_DIR" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort)"
    while IFS= read -r line; do
        [ -n "$line" ] && CREATED_SHARDS+=("$line")
    done <<< "$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))"
}

list_po_shards() {
    find "$PO_LOG_DIR" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort
}

echo "[smoke] Bash syntax check"
bash -n "$AGENTS_DIR/lib/memory.sh"
bash -n "$AGENTS_DIR/activate.sh"
bash -n "$AGENTS_DIR/update_memory.sh"
bash -n "$AGENTS_DIR/status.sh"
bash -n "$AGENTS_DIR/run_chain.sh"
bash -n "$AGENTS_DIR/archive_memory.sh"
bash -n "$AGENTS_DIR/migrate_memory.sh"
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

echo "[smoke] activate.sh is read-only on memory"
before_shards="$(list_po_shards)"
before_state="$(shasum -a 256 "$AGENTS_DIR/pods/po/memory.md" | awk '{print $1}')"
"$AGENTS_DIR/activate.sh" po "smoke read-only" >/dev/null
after_state="$(shasum -a 256 "$AGENTS_DIR/pods/po/memory.md" | awk '{print $1}')"
if [ "$before_state" != "$after_state" ]; then
    echo "activate.sh modified memory.md — it must be read-only"
    exit 1
fi
if [ "$before_shards" != "$(list_po_shards)" ]; then
    echo "activate.sh created a memory shard — it must be read-only"
    exit 1
fi

echo "[smoke] activate.sh --raw emits clean stdout"
raw_out="$("$AGENTS_DIR/activate.sh" --raw po "smoke raw" 2>/dev/null)"
if printf '%s' "$raw_out" | grep -q $'\033'; then
    echo "--raw stdout contains ANSI escapes"
    exit 1
fi
if printf '%s' "$raw_out" | grep -q '\[INFO\]\|\[TIP\]\|Pod Activated'; then
    echo "--raw stdout contains chrome that belongs on stderr"
    exit 1
fi
if ! printf '%s' "$raw_out" | grep -q '=== TASK TO EXECUTE ==='; then
    echo "--raw stdout missing the task section"
    exit 1
fi

echo "[smoke] update_memory strict validation (must fail invalid summary)"
before_shards="$(list_po_shards)"
if "$AGENTS_DIR/update_memory.sh" --strict-validate po "Resumo sem bloco valido" >/dev/null 2>&1; then
    echo "Expected --strict-validate to fail for invalid summary, but it succeeded"
    exit 1
fi
if [ "$before_shards" != "$(list_po_shards)" ]; then
    echo "Memory shard created after strict validation failure"
    exit 1
fi

echo "[smoke] update_memory writes a new shard (never appends)"
before_shards="$(list_po_shards)"
before_count=$(printf '%s\n' "$before_shards" | grep -c . || true)
"$AGENTS_DIR/update_memory.sh" --strict-validate --task="smoke shard" po \
    $'## MEMORY UPDATE\n- shard 1\n- shard 2\n- shard 3' >/dev/null
snapshot_new_shards "$before_shards"
after_count=$(list_po_shards | grep -c . || true)
if [ "$after_count" -ne "$((before_count + 1))" ]; then
    echo "Expected exactly one new shard, got $before_count -> $after_count"
    exit 1
fi

echo "[smoke] shard carries author/branch frontmatter"
newest="$(list_po_shards | tail -1)"
for field in "pod: po" "author:" "branch:" "date:" "task: smoke shard"; do
    if ! grep -q "^$field" "$newest"; then
        echo "Shard missing frontmatter field: $field"
        exit 1
    fi
done

echo "[smoke] concurrent authors never collide on the same file"
before_shards="$(list_po_shards)"
DEVIA_AUTHOR=dev-a "$AGENTS_DIR/update_memory.sh" po $'## MEMORY UPDATE\n- a1\n- a2\n- a3' >/dev/null &
pid_a=$!
DEVIA_AUTHOR=dev-b "$AGENTS_DIR/update_memory.sh" po $'## MEMORY UPDATE\n- b1\n- b2\n- b3' >/dev/null &
pid_b=$!
wait "$pid_a" "$pid_b"
snapshot_new_shards "$before_shards"
new_count=$(comm -13 <(printf '%s\n' "$before_shards") <(list_po_shards) | grep -c . || true)
if [ "$new_count" -ne 2 ]; then
    echo "Expected 2 shards from 2 concurrent authors, got $new_count"
    exit 1
fi

echo "[smoke] update_memory --stdin"
before_shards="$(list_po_shards)"
printf '## MEMORY UPDATE\n- via stdin 1\n- via stdin 2\n- via stdin 3\n' \
    | "$AGENTS_DIR/update_memory.sh" --strict-validate --stdin --task="smoke stdin" po >/dev/null
snapshot_new_shards "$before_shards"
if ! grep -q "via stdin 1" "$(list_po_shards | tail -1)"; then
    echo "--stdin did not persist the piped summary"
    exit 1
fi

echo "[smoke] lock contention on update_memory"
before_shards="$(list_po_shards)"
mkdir -p "$AGENTS_DIR/.locks/po-memory.lock"
( sleep 0.5; rmdir "$AGENTS_DIR/.locks/po-memory.lock" 2>/dev/null || true ) &
"$AGENTS_DIR/update_memory.sh" --strict-validate po $'## MEMORY UPDATE\n- teste lock 1\n- teste lock 2\n- teste lock 3' >/dev/null
snapshot_new_shards "$before_shards"

echo "[smoke] lock timeout on update_memory (must fail)"
before_shards="$(list_po_shards)"
mkdir -p "$AGENTS_DIR/.locks/po-memory.lock"
if LOCK_MAX_ATTEMPTS=3 LOCK_SLEEP_SECONDS=0.01 "$AGENTS_DIR/update_memory.sh" --strict-validate po $'## MEMORY UPDATE\n- timeout 1\n- timeout 2\n- timeout 3' >/dev/null 2>&1; then
    echo "Expected lock-timeout scenario to fail, but it succeeded"
    exit 1
fi
if [ "$before_shards" != "$(list_po_shards)" ]; then
    echo "Shard written despite lock timeout"
    exit 1
fi
rmdir "$AGENTS_DIR/.locks/po-memory.lock" 2>/dev/null || true

echo "[smoke] status.sh reads shards"
"$AGENTS_DIR/status.sh" >/dev/null
"$AGENTS_DIR/status.sh" po >/dev/null

echo "[smoke] status.sh strips frontmatter to find a description"
if "$AGENTS_DIR/status.sh" po | grep -q "(sem descrição)"; then
    echo "status.sh failed to extract a description from a shard body"
    exit 1
fi

echo "[smoke] migrate_memory is idempotent"
"$AGENTS_DIR/migrate_memory.sh" --dry-run >/dev/null
"$AGENTS_DIR/migrate_memory.sh" >/dev/null
if [ ! -f "$PO_LOG_DIR/0000-legacy.md" ]; then
    echo "Legacy shard disappeared after re-running migration"
    exit 1
fi

echo "[smoke] OK"
