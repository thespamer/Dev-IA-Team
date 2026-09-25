#!/bin/bash

# doctor.sh - Verifica setup e consistencia basica do framework
# Uso: ./doctor.sh

set -e

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"
SHARED_DIR="$AGENTS_DIR/context/shared"
CHAINS_DIR="$AGENTS_DIR/chains"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

ok() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "${GREEN}OK${NC}   $1"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    echo -e "${YELLOW}WARN${NC} $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "${RED}FAIL${NC} $1"
}

check_file() {
    local file_path="$1"
    local label="$2"
    if [ -f "$file_path" ]; then
        ok "$label"
    else
        fail "$label"
    fi
}

check_executable() {
    local file_path="$1"
    local label="$2"
    if [ -x "$file_path" ]; then
        ok "$label"
    elif [ -f "$file_path" ]; then
        warn "$label (arquivo existe, mas nao esta executavel)"
    else
        fail "$label"
    fi
}

echo -e "${CYAN}=== Dev-IA-Team Doctor ===${NC}"
echo ""

echo "[1/7] Scripts principais"
check_executable "$AGENTS_DIR/activate.sh" "activate.sh executavel"
check_executable "$AGENTS_DIR/update_memory.sh" "update_memory.sh executavel"
check_executable "$AGENTS_DIR/status.sh" "status.sh executavel"
check_executable "$AGENTS_DIR/run_chain.sh" "run_chain.sh executavel"
check_executable "$AGENTS_DIR/archive_memory.sh" "archive_memory.sh executavel"
check_executable "$AGENTS_DIR/migrate_memory.sh" "migrate_memory.sh executavel"
check_file "$AGENTS_DIR/lib/memory.sh" "lib/memory.sh presente"
check_file "$AGENTS_DIR/lib/artifacts.sh" "lib/artifacts.sh presente"
check_file "$AGENTS_DIR/lib/contract.sh" "lib/contract.sh presente"
echo ""

echo "[2/7] Pods e arquivos obrigatorios"
for pod in po backend frontend qa sec devops; do
    check_file "$PODS_DIR/$pod/PROMPT.md" "$pod/PROMPT.md"
    check_file "$PODS_DIR/$pod/memory.md" "$pod/memory.md"
done
check_file "$AGENTS_DIR/SUPERVISOR.md" "SUPERVISOR.md"
echo ""

echo "[3/7] Contexto compartilhado"
if [ -f "$SHARED_DIR/project.md" ]; then
    if [ -s "$SHARED_DIR/project.md" ]; then
        ok "context/shared/project.md presente e nao vazio"
    else
        warn "context/shared/project.md presente, mas vazio"
    fi
else
    fail "context/shared/project.md ausente"
fi
echo ""

echo "[4/7] Manifestos de leitura (reads.txt)"
# shellcheck source=lib/artifacts.sh
. "$AGENTS_DIR/lib/artifacts.sh"
for pod in po backend frontend qa sec devops supervisor; do
    manifest="$PODS_DIR/$pod/reads.txt"
    if [ ! -f "$manifest" ]; then
        warn "$pod/reads.txt ausente — pod recebe todo context/shared/ no prompt"
        continue
    fi

    invalid="$(artifacts_for_pod "$PODS_DIR" "$SHARED_DIR" "$pod" 2>&1 >/dev/null || true)"
    if [ -n "$invalid" ]; then
        fail "$pod/reads.txt com entrada invalida"
        echo "$invalid" | sed "s/^/       /"
        continue
    fi

    declared=$(artifacts_for_pod "$PODS_DIR" "$SHARED_DIR" "$pod" | wc -l | tr -d " ")
    missing="$(artifacts_missing_for_pod "$PODS_DIR" "$SHARED_DIR" "$pod" | tr "\n" " ")"
    if [ -n "$missing" ]; then
        ok "$pod/reads.txt valido ($declared disponivel(is); ainda nao produzido: $missing)"
    else
        ok "$pod/reads.txt valido ($declared artefato(s) disponivel(is))"
    fi
done
echo ""

echo "[5/7] Contrato de memoria nos prompts"
for pod in po backend frontend qa sec devops; do
    prompt="$PODS_DIR/$pod/PROMPT.md"
    [ -f "$prompt" ] || continue
    if grep -q "^## MEMORY UPDATE" "$prompt"; then
        ok "$pod/PROMPT.md exige o bloco MEMORY UPDATE"
    else
        fail "$pod/PROMPT.md sem o bloco MEMORY UPDATE — update_memory.sh vai recusar o output"
    fi
done
echo ""

echo "[6/7] Chain files"
if ls "$CHAINS_DIR"/*.chain >/dev/null 2>&1; then
    for chain in "$CHAINS_DIR"/*.chain; do
        if grep -q "^name=" "$chain"; then
            ok "$(basename "$chain") com cabecalho name="
        else
            warn "$(basename "$chain") sem cabecalho name="
        fi

        if grep -Eq "^step |^parallel " "$chain"; then
            ok "$(basename "$chain") com steps"
        else
            warn "$(basename "$chain") sem steps"
        fi
    done
else
    warn "Nenhum arquivo .chain encontrado em chains/"
fi
echo ""

echo "[7/7] Integridade basica de memoria"
for pod in po backend frontend qa sec devops supervisor; do
    mem="$PODS_DIR/$pod/memory.md"
    log_dir="$PODS_DIR/$pod/memory"

    if [ -f "$mem" ] && grep -q "^# " "$mem"; then
        ok "$pod/memory.md com cabecalho markdown"
    elif [ -f "$mem" ]; then
        warn "$pod/memory.md sem cabecalho markdown inicial"
    else
        warn "$pod/memory.md ausente"
    fi

    if [ -d "$log_dir" ]; then
        shard_count=$(find "$log_dir" -maxdepth 1 -type f -name "*.md" | wc -l | tr -d " ")
        ok "$pod/memory/ presente ($shard_count entrada(s) ativa(s))"
    else
        warn "$pod/memory/ ausente — rode ./migrate_memory.sh"
    fi
done
echo ""

# Contrato de memoria: entradas gravadas com --no-contract ficam marcadas, para
# a squad ver o quanto esta driblando a validacao.
unverified_total=0
for pod in po backend frontend qa sec devops supervisor; do
    log_dir="$PODS_DIR/$pod/memory"
    [ -d "$log_dir" ] || continue
    n=$(grep -l "^contract: unverified" "$log_dir"/*.md 2>/dev/null | wc -l | tr -d " ")
    unverified_total=$((unverified_total + n))
    [ "$n" -gt 0 ] && warn "$pod: $n entrada(s) gravada(s) com --no-contract"
done
if [ "$unverified_total" -eq 0 ]; then
    ok "nenhuma entrada de memoria gravada com --no-contract"
fi
echo ""

# Memoria em shards: nenhum log legado pode ter sobrado dentro do estado curado
for pod in po backend frontend qa sec devops supervisor; do
    mem="$PODS_DIR/$pod/memory.md"
    [ -f "$mem" ] || continue
    if grep -q "^## Tarefa Executada\|^### Output salvo em" "$mem"; then
        warn "$pod/memory.md ainda tem log no formato antigo — rode ./migrate_memory.sh"
    fi
done
echo ""

echo -e "${CYAN}Resumo:${NC} ${GREEN}$PASS_COUNT ok${NC}, ${YELLOW}$WARN_COUNT avisos${NC}, ${RED}$FAIL_COUNT falhas${NC}"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi

exit 0
