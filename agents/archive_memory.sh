#!/bin/bash

# archive_memory.sh - Move entradas antigas de memory/ para memory/archive/
#
# Uso: ./archive_memory.sh [pod] [--keep=N]
#   sem pod:    arquiva todos os pods
#   --keep=N:   mantem as N entradas mais recentes ativas (default: 20)
#
# Com memoria em shards, arquivar e mover arquivo — nao cirurgia de linha no
# meio de um markdown. As entradas continuam versionadas em archive/, so param
# de entrar no prompt montado por activate.sh.
#
# Exemplos:
#   ./archive_memory.sh                    # arquiva todos, mantem 20 entradas cada
#   ./archive_memory.sh backend            # arquiva so backend
#   ./archive_memory.sh backend --keep=10  # mantem 10 entradas no backend

set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"

# shellcheck source=lib/memory.sh
. "$AGENTS_DIR/lib/memory.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

KEEP=20
TARGET_POD=""

for arg in "$@"; do
    case "$arg" in
        --keep=*) KEEP="${arg#*=}" ;;
        --*) echo -e "${RED}Flag desconhecida: $arg${NC}" >&2; exit 1 ;;
        *) TARGET_POD="$arg" ;;
    esac
done

if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Erro: --keep precisa ser um inteiro >= 0${NC}" >&2
    exit 1
fi

archive_pod() {
    local pod="$1"
    local shards total to_archive archive_dir moved=0

    shards="$(memory_list_shards "$PODS_DIR" "$pod")"
    if [ -z "$shards" ]; then
        echo -e "  ${YELLOW}[$pod]${NC} sem entradas ativas"
        return
    fi

    total=$(printf '%s\n' "$shards" | grep -c .)
    if [ "$total" -le "$KEEP" ]; then
        echo -e "  ${YELLOW}[$pod]${NC} $total entrada(s) — abaixo do limite ($KEEP), nada arquivado"
        return
    fi

    to_archive=$((total - KEEP))
    archive_dir="$(memory_archive_dir "$PODS_DIR" "$pod")"
    mkdir -p "$archive_dir"

    # Shards saem ordenados por timestamp: as primeiras sao as mais antigas.
    while IFS= read -r shard; do
        [ -n "$shard" ] || continue
        mv "$shard" "$archive_dir/$(basename "$shard")"
        moved=$((moved + 1))
    done <<< "$(printf '%s\n' "$shards" | head -n "$to_archive")"

    echo -e "  ${GREEN}[$pod]${NC} $moved entrada(s) → memory/archive/  (mantidas ativas: $KEEP)"
}

echo -e "${CYAN}=== archive_memory.sh — mantendo últimas $KEEP entradas por pod ===${NC}"
echo ""

if [ -n "$TARGET_POD" ]; then
    if ! memory_is_valid_pod "$TARGET_POD"; then
        echo -e "${RED}Pod '$TARGET_POD' inválido. Disponíveis: ${MEMORY_VALID_PODS[*]}${NC}" >&2
        exit 1
    fi
    archive_pod "$TARGET_POD"
else
    for pod in "${MEMORY_VALID_PODS[@]}"; do
        archive_pod "$pod"
    done
fi

echo ""
echo -e "${GREEN}✓ Arquivamento concluído${NC}"
