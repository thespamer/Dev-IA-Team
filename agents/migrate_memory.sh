#!/bin/bash

# migrate_memory.sh - Migracao unica: memory.md monolitico -> memory.md + memory/
#
# Uso: ./migrate_memory.sh [--dry-run]
#
# O memory.md antigo misturava duas coisas:
#   1. Estado curado do pod (tabelas de schema, endpoints, decisoes)
#   2. Log de execucao anexado no fim (## Tarefa Executada / ### Output salvo em)
#
# Esta migracao separa as duas. O estado curado FICA em memory.md. O log
# historico inteiro vai para memory/0000-legacy.md, preservado como bloco unico —
# o formato novo em shards comeca do zero a partir da proxima entrada.
#
# Idempotente: pods ja migrados sao pulados.

set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"

# shellcheck source=lib/memory.sh
. "$AGENTS_DIR/lib/memory.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

LEGACY_MARKER='^## Tarefa Executada\|^### Output salvo em'

migrate_pod() {
    local pod="$1"
    local state_file log_dir legacy_file first_line header_lines

    state_file="$(memory_state_file "$PODS_DIR" "$pod")"
    log_dir="$(memory_log_dir "$PODS_DIR" "$pod")"
    legacy_file="$log_dir/0000-legacy.md"

    [ -f "$state_file" ] || { echo -e "  ${YELLOW}[$pod]${NC} sem memory.md, pulado"; return; }

    if [ -f "$legacy_file" ]; then
        echo -e "  ${YELLOW}[$pod]${NC} já migrado (0000-legacy.md existe)"
        return
    fi

    first_line="$(grep -n "$LEGACY_MARKER" "$state_file" | head -1 | cut -d: -f1 || true)"
    if [ -z "$first_line" ]; then
        [ "$DRY_RUN" = false ] && mkdir -p "$log_dir"
        echo -e "  ${GREEN}[$pod]${NC} sem log legado — só memory/ criado"
        return
    fi

    header_lines=$((first_line - 1))

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${CYAN}[$pod]${NC} [dry-run] header=${header_lines}L  legado=$(($(wc -l < "$state_file") - header_lines))L → 0000-legacy.md"
        return
    fi

    mkdir -p "$log_dir"

    {
        echo "---"
        echo "pod: $pod"
        echo "author: legacy"
        echo "date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "note: historico anterior a migracao para memoria em shards"
        echo "---"
        echo ""
        tail -n "+$first_line" "$state_file"
    } > "$legacy_file"

    head -n "$header_lines" "$state_file" > "$state_file.tmp"
    mv "$state_file.tmp" "$state_file"

    echo -e "  ${GREEN}[$pod]${NC} log legado → memory/0000-legacy.md  (estado curado mantido em memory.md)"
}

echo -e "${CYAN}=== migrate_memory.sh — memory.md monolítico → memory.md + memory/ ===${NC}"
[ "$DRY_RUN" = true ] && echo -e "${YELLOW}[DRY RUN] nenhum arquivo será alterado${NC}"
echo ""

for pod in "${MEMORY_VALID_PODS[@]}"; do
    migrate_pod "$pod"
done

echo ""
echo -e "${GREEN}✓ Migração concluída${NC}"
