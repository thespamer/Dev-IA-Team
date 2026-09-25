#!/bin/bash

# status.sh - Mostra histórico de entradas de memória de todos os pods
# Uso: ./status.sh [pod]
#   sem argumento: resumo de todos os pods
#   com pod:       histórico completo do pod

set -uo pipefail

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"

# shellcheck source=lib/memory.sh
. "$AGENTS_DIR/lib/memory.sh"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# case em vez de array associativo: bash 3.2 (padrao no macOS) nao tem declare -A.
pod_display_name() {
    case "$1" in
        po)         echo "Product Owner" ;;
        backend)    echo "Backend Developers" ;;
        frontend)   echo "Frontend Developers" ;;
        qa)         echo "Quality Assurance" ;;
        sec)        echo "Security Engineers" ;;
        devops)     echo "DevOps Analysts" ;;
        supervisor) echo "Supervisor" ;;
        *)          echo "$1" ;;
    esac
}

# Rotulo curto de um shard: data, autor e tarefa (ou primeira linha util).
shard_label() {
    local shard="$1" date author task
    date="$(memory_shard_field "$shard" "date")"
    author="$(memory_shard_field "$shard" "author")"
    task="$(memory_shard_field "$shard" "task")"

    if [ -z "$task" ]; then
        task="$(memory_shard_body "$shard" | grep -v '^#' | grep -m1 . || true)"
    fi
    [ -z "$date" ] && date="$(basename "$shard" | cut -d- -f1)"
    [ -z "$author" ] && author="?"

    printf '%s\t%s\t%s' "$date" "$author" "${task:-(sem descrição)}"
}

show_pod_detail() {
    local pod="$1" shards archive_count

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  $(pod_display_name "$pod") — Histórico Completo"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    shards="$(memory_list_shards "$PODS_DIR" "$pod")"
    if [ -z "$shards" ]; then
        echo -e "  ${RED}(sem entradas)${NC}"
        echo ""
        return
    fi

    while IFS= read -r shard; do
        [ -n "$shard" ] || continue
        IFS=$'\t' read -r date author task <<< "$(shard_label "$shard")"
        echo -e "  ${YELLOW}▶ $date${NC}  ${CYAN}@$author${NC}"
        echo -e "    └─ $(echo "$task" | cut -c1-80)"
    done <<< "$shards"

    archive_count=$(find "$(memory_archive_dir "$PODS_DIR" "$pod")" -maxdepth 1 -type f -name '*.md' 2>/dev/null | grep -c . || true)
    if [ "$archive_count" -gt 0 ]; then
        echo ""
        echo -e "  ${YELLOW}+ $archive_count entrada(s) em memory/archive/${NC}"
    fi
    echo ""
}

show_all_summary() {
    local total_entries=0 pod count shards last_shard

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Dev-IA-Team — Status Geral                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    for pod in "${MEMORY_VALID_PODS[@]}"; do
        [ -f "$(memory_state_file "$PODS_DIR" "$pod")" ] || continue

        shards="$(memory_list_shards "$PODS_DIR" "$pod")"
        count=$(printf '%s\n' "$shards" | grep -c . || true)
        total_entries=$((total_entries + count))

        if [ "$count" -gt 0 ]; then
            last_shard="$(printf '%s\n' "$shards" | tail -1)"
            IFS=$'\t' read -r date author task <<< "$(shard_label "$last_shard")"
            echo -e "${GREEN}●${NC} ${YELLOW}[$pod]${NC} $(pod_display_name "$pod")"
            echo -e "    Entradas: ${CYAN}$count${NC}  |  Última: $date  ${CYAN}@$author${NC}"
            echo -e "    └─ $(echo "$task" | cut -c1-75)"
        else
            echo -e "${RED}○${NC} ${YELLOW}[$pod]${NC} $(pod_display_name "$pod")  ${RED}(sem entradas)${NC}"
        fi
        echo ""
    done

    echo -e "Total de entradas de memória: ${CYAN}$total_entries${NC}"
    echo ""

    SHARED_DIR="$AGENTS_DIR/context/shared"
    if [ -d "$SHARED_DIR" ]; then
        artifact_count=0
        for f in "$SHARED_DIR"/*.md; do
            [ -f "$f" ] && [ -s "$f" ] && artifact_count=$((artifact_count + 1))
        done

        if [ "$artifact_count" -gt 0 ]; then
            echo -e "${CYAN}=== Artefatos Compartilhados ($artifact_count) ===${NC}"
            for f in "$SHARED_DIR"/*.md; do
                if [ -f "$f" ] && [ -s "$f" ]; then
                    size=$(wc -l < "$f")
                    name=$(basename "$f")
                    echo -e "  ${YELLOW}$name${NC}  ($size linhas)"
                fi
            done
            echo ""
        fi
    fi
}

if [ -n "${1:-}" ]; then
    if ! memory_is_valid_pod "$1"; then
        echo -e "${RED}Pod '$1' inválido. Disponíveis: ${MEMORY_VALID_PODS[*]}${NC}" >&2
        exit 1
    fi
    show_pod_detail "$1"
else
    show_all_summary
fi
