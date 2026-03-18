#!/bin/bash

# archive_memory.sh - Arquiva entradas antigas do memory.md
# Mantém as últimas N tarefas em memory.md e move o restante para memory_archive.md
#
# Uso: ./archive_memory.sh [pod] [--keep=N]
#   sem pod:    arquiva todos os pods
#   --keep=N:   mantém as últimas N tarefas (default: 20)
#
# Exemplos:
#   ./archive_memory.sh                    # arquiva todos, mantém 20 tarefas cada
#   ./archive_memory.sh backend            # arquiva só backend
#   ./archive_memory.sh backend --keep=10  # mantém 10 tarefas no backend

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

KEEP=20
TARGET_POD=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        --keep=*) KEEP="${arg#*=}" ;;
        --*) echo -e "${RED}Flag desconhecida: $arg${NC}"; exit 1 ;;
        *) TARGET_POD="$arg" ;;
    esac
done

ALL_PODS=("po" "backend" "frontend" "qa" "sec" "devops" "supervisor")

get_memory_file() {
    local pod="$1"
    if [ "$pod" = "supervisor" ]; then
        echo "$PODS_DIR/supervisor/memory.md"
    else
        echo "$PODS_DIR/$pod/memory.md"
    fi
}

archive_pod() {
    local pod="$1"
    local memory_file
    memory_file=$(get_memory_file "$pod")

    [ ! -f "$memory_file" ] && return

    local task_count
    task_count=$(grep -c "^## Tarefa Executada" "$memory_file" 2>/dev/null || echo "0")

    if [ "$task_count" -le "$KEEP" ]; then
        echo -e "  ${YELLOW}[$pod]${NC} $task_count tarefas — abaixo do limite ($KEEP), nada arquivado"
        return
    fi

    local to_archive=$((task_count - KEEP))
    local archive_file
    if [ "$pod" = "supervisor" ]; then
        archive_file="$PODS_DIR/supervisor/memory_archive.md"
    else
        archive_file="$PODS_DIR/$pod/memory_archive.md"
    fi

    # Separar o cabeçalho (tudo antes da primeira tarefa) do histórico de tarefas
    local first_task_line
    first_task_line=$(grep -n "^## Tarefa Executada" "$memory_file" | head -1 | cut -d: -f1)

    if [ -z "$first_task_line" ]; then
        echo -e "  ${YELLOW}[$pod]${NC} Nenhuma entrada de tarefa encontrada"
        return
    fi

    # Cabeçalho = linhas antes da primeira tarefa
    local header
    header=$(head -n $((first_task_line - 1)) "$memory_file")

    # Todas as linhas de tarefa agrupadas (cada tarefa começa com "## Tarefa Executada")
    # Separar em blocos por tarefa
    local tmp_tasks
    tmp_tasks=$(mktemp)
    tail -n "+$first_task_line" "$memory_file" > "$tmp_tasks"

    # Contar início de cada bloco de tarefa
    local task_starts
    task_starts=$(grep -n "^## Tarefa Executada" "$tmp_tasks" | cut -d: -f1)
    local task_starts_array=($task_starts)
    local total=${#task_starts_array[@]}

    # Linha de início das tarefas a arquivar (as mais antigas = primeiras)
    local archive_end_task=$((to_archive))
    local last_archive_start=${task_starts_array[$((archive_end_task - 1))]}

    # Próximo bloco = início das tarefas a manter
    local keep_start
    if [ "$archive_end_task" -lt "$total" ]; then
        keep_start=${task_starts_array[$archive_end_task]}
    else
        keep_start=$(($(wc -l < "$tmp_tasks") + 1))
    fi

    # Append no arquivo de archive
    {
        echo ""
        echo "## Archived em $(date '+%Y-%m-%d %H:%M:%S') — $to_archive entrada(s)"
        echo ""
        head -n $((keep_start - 1)) "$tmp_tasks"
    } >> "$archive_file"

    # Reescrever memory.md com cabeçalho + tarefas recentes
    {
        echo "$header"
        echo ""
        tail -n "+$keep_start" "$tmp_tasks"
    } > "$memory_file"

    rm "$tmp_tasks"

    echo -e "  ${GREEN}[$pod]${NC} Arquivadas $to_archive tarefas → $(basename "$archive_file")  (mantidas: $KEEP)"
}

echo -e "${CYAN}=== archive_memory.sh — mantendo últimas $KEEP tarefas por pod ===${NC}"
echo ""

if [ -n "$TARGET_POD" ]; then
    VALID_PODS=("po" "qa" "backend" "frontend" "sec" "devops" "supervisor")
    if [[ ! " ${VALID_PODS[@]} " =~ " $TARGET_POD " ]]; then
        echo -e "${RED}Pod '$TARGET_POD' inválido${NC}"
        exit 1
    fi
    archive_pod "$TARGET_POD"
else
    for pod in "${ALL_PODS[@]}"; do
        archive_pod "$pod"
    done
fi

echo ""
echo -e "${GREEN}✓ Arquivamento concluído${NC}"
