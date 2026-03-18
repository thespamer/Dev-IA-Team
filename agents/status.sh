#!/bin/bash

# status.sh - Mostra histórico de tarefas de todos os pods
# Uso: ./status.sh [pod]
#   sem argumento: mostra resumo de todos os pods
#   com pod:       mostra histórico completo do pod

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

ALL_PODS=("po" "backend" "frontend" "qa" "sec" "devops" "supervisor")
declare -A POD_NAMES=(
    [po]="Product Owner"
    [backend]="Backend Developers"
    [frontend]="Frontend Developers"
    [qa]="Quality Assurance"
    [sec]="Security Engineers"
    [devops]="DevOps Analysts"
    [supervisor]="Supervisor"
)

get_memory_file() {
    local pod="$1"
    if [ "$pod" = "supervisor" ]; then
        echo "$PODS_DIR/supervisor/memory.md"
    else
        echo "$PODS_DIR/$pod/memory.md"
    fi
}

show_pod_detail() {
    local pod="$1"
    local memory_file
    memory_file=$(get_memory_file "$pod")

    if [ ! -f "$memory_file" ]; then
        echo -e "${RED}memory.md não encontrado para '$pod'${NC}"
        return
    fi

    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${POD_NAMES[$pod]} — Histórico Completo"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    grep -n "^## Tarefa Executada\|^\*\*Task\*\*" "$memory_file" | while IFS= read -r line; do
        if echo "$line" | grep -q "## Tarefa Executada"; then
            timestamp=$(echo "$line" | sed 's/.*## Tarefa Executada em //')
            echo -e "  ${YELLOW}▶ $timestamp${NC}"
        else
            task=$(echo "$line" | sed 's/.*\*\*Task\*\*: //')
            echo -e "    └─ $(echo "$task" | cut -c1-80)"
        fi
    done
    echo ""
}

show_all_summary() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Dev-IA-Team — Status Geral                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    total_tasks=0

    for pod in "${ALL_PODS[@]}"; do
        memory_file=$(get_memory_file "$pod")
        [ ! -f "$memory_file" ] && continue

        task_count=$(grep -c "^## Tarefa Executada" "$memory_file" 2>/dev/null || echo "0")
        total_tasks=$((total_tasks + task_count))

        last_timestamp=$(grep "^## Tarefa Executada" "$memory_file" 2>/dev/null | tail -1 | sed 's/## Tarefa Executada em //')
        last_task=$(grep -A1 "^## Tarefa Executada" "$memory_file" 2>/dev/null | grep "^\*\*Task\*\*" | tail -1 | sed 's/\*\*Task\*\*: //')

        if [ "$task_count" -gt 0 ]; then
            echo -e "${GREEN}●${NC} ${YELLOW}[$pod]${NC} ${POD_NAMES[$pod]}"
            echo -e "    Tasks: ${CYAN}$task_count${NC}  |  Última: $last_timestamp"
            if [ -n "$last_task" ]; then
                echo -e "    └─ $(echo "$last_task" | cut -c1-75)..."
            fi
        else
            echo -e "${RED}○${NC} ${YELLOW}[$pod]${NC} ${POD_NAMES[$pod]}  ${RED}(sem tarefas)${NC}"
        fi
        echo ""
    done

    echo -e "Total de tarefas executadas: ${CYAN}$total_tasks${NC}"
    echo ""

    # Shared artifacts
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

# Entry point
if [ -n "$1" ]; then
    VALID_PODS=("po" "qa" "backend" "frontend" "sec" "devops" "supervisor")
    if [[ ! " ${VALID_PODS[@]} " =~ " $1 " ]]; then
        echo -e "${RED}Pod '$1' inválido. Disponíveis: ${VALID_PODS[*]}${NC}"
        exit 1
    fi
    show_pod_detail "$1"
else
    show_all_summary
fi
