#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="$ROOT_DIR/agents"
PO_LOG_DIR="$AGENTS_DIR/pods/po/memory"
CREATED_SHARDS=()
SMOKE_ARTIFACTS=()
MANIFEST_BAK=""
LAST_NEW_SHARD=""

cleanup() {
    local shard artifact
    for shard in "${CREATED_SHARDS[@]:-}"; do
        [ -n "$shard" ] && rm -f "$shard"
    done
    for artifact in "${SMOKE_ARTIFACTS[@]:-}"; do
        [ -n "$artifact" ] && rm -f "$artifact"
    done
    if [ -n "$MANIFEST_BAK" ] && [ -f "$MANIFEST_BAK" ]; then
        cp "$MANIFEST_BAK" "$AGENTS_DIR/pods/devops/reads.txt"
        rm -f "$MANIFEST_BAK"
    fi
    rm -rf "$AGENTS_DIR/.locks/po-memory.lock" 2>/dev/null || true
}

trap cleanup EXIT

# Registra os shards criados desde "$before" para o cleanup remover, e guarda o
# ultimo em LAST_NEW_SHARD. Os testes usam essa variavel em vez de 'tail -1':
# shards escritos no mesmo segundo ordenam pelo slug, nao pela ordem de escrita.
snapshot_new_shards() {
    local before="$1" after
    after="$(find "$PO_LOG_DIR" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort)"
    LAST_NEW_SHARD=""
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        CREATED_SHARDS+=("$line")
        LAST_NEW_SHARD="$line"
    done <<< "$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))"
}

list_po_shards() {
    find "$PO_LOG_DIR" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort
}

echo "[smoke] Bash syntax check"
bash -n "$AGENTS_DIR/lib/memory.sh"
bash -n "$AGENTS_DIR/lib/artifacts.sh"
bash -n "$AGENTS_DIR/lib/contract.sh"
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

echo "[smoke] every pod activates cleanly with no shared artifacts present"
# Regressao: artifacts_for_pod retornava 1 quando nada casava no manifesto, e o
# 'set -e' do activate.sh matava a montagem do prompt no meio, em silencio.
for pod in po backend frontend qa sec devops supervisor; do
    if ! "$AGENTS_DIR/activate.sh" --raw "$pod" "smoke empty artifacts" >/dev/null 2>&1; then
        echo "activate.sh failed for pod '$pod' with no artifacts in context/shared/"
        exit 1
    fi
done

echo "[smoke] reads.txt selects only the declared artifacts"
ART_DIR="$AGENTS_DIR/context/shared"
for name in api_spec schemas user_stories bugs; do
    printf '# %s\nsmoke artifact %s\n' "$name" "$name" > "$ART_DIR/$name.md"
    SMOKE_ARTIFACTS+=("$ART_DIR/$name.md")
done

# qa declara api_spec + schemas + user_stories (nao bugs); devops declara api_spec
# + schemas (nao user_stories nem bugs).
qa_out="$("$AGENTS_DIR/activate.sh" --raw qa "smoke manifest" 2>/dev/null)"
if ! printf '%s' "$qa_out" | grep -q 'smoke artifact api_spec'; then
    echo "qa did not receive api_spec.md, which its reads.txt declares"
    exit 1
fi
if printf '%s' "$qa_out" | grep -q 'smoke artifact bugs'; then
    echo "qa received bugs.md, which its reads.txt does not declare"
    exit 1
fi

devops_out="$("$AGENTS_DIR/activate.sh" --raw devops "smoke manifest" 2>/dev/null)"
if printf '%s' "$devops_out" | grep -q 'smoke artifact user_stories'; then
    echo "devops received user_stories.md, which its reads.txt does not declare"
    exit 1
fi

echo "[smoke] supervisor reads every artifact (manifest is '*')"
sup_out="$("$AGENTS_DIR/activate.sh" --raw supervisor "smoke manifest" 2>/dev/null)"
for name in api_spec schemas user_stories bugs; do
    if ! printf '%s' "$sup_out" | grep -q "smoke artifact $name"; then
        echo "supervisor missed $name.md despite the '*' manifest"
        exit 1
    fi
done

echo "[smoke] reads.txt rejects paths outside context/shared/"
manifest_bak="$(mktemp)"
cp "$AGENTS_DIR/pods/devops/reads.txt" "$manifest_bak"
MANIFEST_BAK="$manifest_bak"
printf '../../../../etc/passwd\nsubdir/x.md\napi_spec.md\n' > "$AGENTS_DIR/pods/devops/reads.txt"
traversal_out="$("$AGENTS_DIR/activate.sh" --raw devops "smoke traversal" 2>/dev/null)"
traversal_err="$("$AGENTS_DIR/activate.sh" --raw devops "smoke traversal" 2>&1 >/dev/null)"
if printf '%s' "$traversal_out" | grep -q 'root:'; then
    echo "activate.sh leaked /etc/passwd into the prompt"
    exit 1
fi
if ! printf '%s' "$traversal_err" | grep -q 'entrada invalida'; then
    echo "invalid manifest entries were not reported on stderr"
    exit 1
fi
if ! printf '%s' "$traversal_out" | grep -q 'smoke artifact api_spec'; then
    echo "valid entry was dropped alongside the invalid ones"
    exit 1
fi
cp "$manifest_bak" "$AGENTS_DIR/pods/devops/reads.txt"
rm -f "$manifest_bak"
MANIFEST_BAK=""

echo "[smoke] memory contract is enforced by default (no flag needed)"
before_shards="$(list_po_shards)"
if "$AGENTS_DIR/update_memory.sh" po "Resumo sem bloco valido" >/dev/null 2>&1; then
    echo "Expected the contract to be enforced by default, but the write succeeded"
    exit 1
fi
if [ "$before_shards" != "$(list_po_shards)" ]; then
    echo "Memory shard created after a contract failure"
    exit 1
fi

echo "[smoke] contract rejects template placeholder bullets"
before_shards="$(list_po_shards)"
if "$AGENTS_DIR/update_memory.sh" po $'## MEMORY UPDATE\n- [User stories criadas: IDs]\n- [Decisoes de MVP: escopo]\n- [Prioridades: MoSCoW]' >/dev/null 2>&1; then
    echo "Expected placeholder-only bullets to be rejected"
    exit 1
fi
if [ "$before_shards" != "$(list_po_shards)" ]; then
    echo "Memory shard created from placeholder-only bullets"
    exit 1
fi

echo "[smoke] contract failure message names the escape hatch"
contract_err="$("$AGENTS_DIR/update_memory.sh" po "sem bloco" 2>&1 >/dev/null || true)"
if ! printf '%s' "$contract_err" | grep -q -- "--no-contract"; then
    echo "Contract failure message must tell the dev how to proceed"
    exit 1
fi

echo "[smoke] contract keeps bullets that merely start with a bracket"
before_shards="$(list_po_shards)"
"$AGENTS_DIR/update_memory.sh" --task="smoke bracket" po \
    $'## MEMORY UPDATE\n- [US-001] Login com email e senha\n- [US-002] Logout invalida sessao\n- [US-003] Reset de senha por email' >/dev/null
snapshot_new_shards "$before_shards"

echo "[smoke] contract extracts the block out of a full AI response"
before_shards="$(list_po_shards)"
printf 'Segue o codigo:\n\n```js\nconst x = 1;\n```\n\nExplicacao longa que nao deve ir para a memoria.\n\n## MEMORY UPDATE\n- US-010 login social com Google definida\n- US-011 login com GitHub fica para a fase 2\n- MVP inclui apenas Google\n\n## Proximos passos\n- esta secao nao deve ser persistida\n' \
    | "$AGENTS_DIR/update_memory.sh" --stdin --task="smoke extract" po >/dev/null
snapshot_new_shards "$before_shards"
extracted="$LAST_NEW_SHARD"
if grep -q "const x = 1" "$extracted"; then
    echo "The AI code block leaked into memory; only the MEMORY UPDATE block should persist"
    exit 1
fi
if grep -q "esta secao nao deve ser persistida" "$extracted"; then
    echo "Content after the MEMORY UPDATE block leaked into memory"
    exit 1
fi
if ! grep -q "US-010 login social com Google definida" "$extracted"; then
    echo "The MEMORY UPDATE block itself was not persisted"
    exit 1
fi
if ! grep -q "^contract: verified" "$extracted"; then
    echo "Shard missing 'contract: verified' stamp"
    exit 1
fi

echo "[smoke] --no-contract writes but stamps the entry unverified"
before_shards="$(list_po_shards)"
"$AGENTS_DIR/update_memory.sh" --no-contract --task="smoke unverified" po "nota solta sem bloco" >/dev/null
snapshot_new_shards "$before_shards"
unverified="$LAST_NEW_SHARD"
if ! grep -q "^contract: unverified" "$unverified"; then
    echo "--no-contract must stamp the entry 'contract: unverified' for auditing"
    exit 1
fi

echo "[smoke] deprecated validation flags still accepted"
before_shards="$(list_po_shards)"
"$AGENTS_DIR/update_memory.sh" --strict-validate --task="smoke compat" po \
    $'## MEMORY UPDATE\n- compat bullet um com conteudo\n- compat bullet dois com conteudo\n- compat bullet tres com conteudo' >/dev/null
snapshot_new_shards "$before_shards"

echo "[smoke] update_memory writes a new shard (never appends)"
before_shards="$(list_po_shards)"
before_count=$(printf '%s\n' "$before_shards" | grep -c . || true)
"$AGENTS_DIR/update_memory.sh" --task="smoke shard" po \
    $'## MEMORY UPDATE\n- shard bullet um com conteudo real\n- shard bullet dois com conteudo real\n- shard bullet tres com conteudo real' >/dev/null
snapshot_new_shards "$before_shards"
after_count=$(list_po_shards | grep -c . || true)
if [ "$after_count" -ne "$((before_count + 1))" ]; then
    echo "Expected exactly one new shard, got $before_count -> $after_count"
    exit 1
fi

echo "[smoke] shard carries author/branch frontmatter"
newest="$LAST_NEW_SHARD"
for field in "pod: po" "author:" "branch:" "date:" "task: smoke shard"; do
    if ! grep -q "^$field" "$newest"; then
        echo "Shard missing frontmatter field: $field"
        exit 1
    fi
done

echo "[smoke] concurrent authors never collide on the same file"
before_shards="$(list_po_shards)"
DEVIA_AUTHOR=dev-a "$AGENTS_DIR/update_memory.sh" po $'## MEMORY UPDATE\n- autor a decisao um\n- autor a decisao dois\n- autor a decisao tres' >/dev/null &
pid_a=$!
DEVIA_AUTHOR=dev-b "$AGENTS_DIR/update_memory.sh" po $'## MEMORY UPDATE\n- autor b decisao um\n- autor b decisao dois\n- autor b decisao tres' >/dev/null &
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
printf '## MEMORY UPDATE\n- via stdin decisao um\n- via stdin decisao dois\n- via stdin decisao tres\n' \
    | "$AGENTS_DIR/update_memory.sh" --stdin --task="smoke stdin" po >/dev/null
snapshot_new_shards "$before_shards"
if ! grep -q "via stdin decisao um" "$LAST_NEW_SHARD"; then
    echo "--stdin did not persist the piped summary"
    exit 1
fi

echo "[smoke] lock contention on update_memory"
before_shards="$(list_po_shards)"
mkdir -p "$AGENTS_DIR/.locks/po-memory.lock"
( sleep 0.5; rmdir "$AGENTS_DIR/.locks/po-memory.lock" 2>/dev/null || true ) &
"$AGENTS_DIR/update_memory.sh" po $'## MEMORY UPDATE\n- teste de lock decisao um\n- teste de lock decisao dois\n- teste de lock decisao tres' >/dev/null
snapshot_new_shards "$before_shards"

echo "[smoke] lock timeout on update_memory (must fail)"
before_shards="$(list_po_shards)"
mkdir -p "$AGENTS_DIR/.locks/po-memory.lock"
if LOCK_MAX_ATTEMPTS=3 LOCK_SLEEP_SECONDS=0.01 "$AGENTS_DIR/update_memory.sh" po $'## MEMORY UPDATE\n- timeout decisao um\n- timeout decisao dois\n- timeout decisao tres' >/dev/null 2>&1; then
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
