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

echo "[1/5] Scripts principais"
check_executable "$AGENTS_DIR/activate.sh" "activate.sh executavel"
check_executable "$AGENTS_DIR/update_memory.sh" "update_memory.sh executavel"
check_executable "$AGENTS_DIR/status.sh" "status.sh executavel"
check_executable "$AGENTS_DIR/run_chain.sh" "run_chain.sh executavel"
check_executable "$AGENTS_DIR/archive_memory.sh" "archive_memory.sh executavel"
echo ""

echo "[2/5] Pods e arquivos obrigatorios"
for pod in po backend frontend qa sec devops; do
    check_file "$PODS_DIR/$pod/PROMPT.md" "$pod/PROMPT.md"
    check_file "$PODS_DIR/$pod/memory.md" "$pod/memory.md"
done
check_file "$AGENTS_DIR/SUPERVISOR.md" "SUPERVISOR.md"
echo ""

echo "[3/5] Contexto compartilhado"
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

echo "[4/5] Chain files"
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

echo "[5/5] Integridade basica de memoria"
for pod in po backend frontend qa sec devops; do
    mem="$PODS_DIR/$pod/memory.md"
    if grep -q "^# " "$mem"; then
        ok "$pod/memory.md com cabecalho markdown"
    else
        warn "$pod/memory.md sem cabecalho markdown inicial"
    fi
done
echo ""

echo -e "${CYAN}Resumo:${NC} ${GREEN}$PASS_COUNT ok${NC}, ${YELLOW}$WARN_COUNT avisos${NC}, ${RED}$FAIL_COUNT falhas${NC}"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi

exit 0
