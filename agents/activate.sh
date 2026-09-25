#!/bin/bash

# activate.sh - Ativa um pod especializado com contexto completo
# Uso: ./activate.sh [--raw] [--memory-limit=N] <pod-name> "<task>"
#
# Flags:
#   --raw              Emite SOMENTE o prompt em stdout (banner/dicas vao para stderr).
#                      Use para pipe em agente headless:
#                        ./activate.sh --raw backend "task" | claude -p
#   --memory-limit=N   Le apenas as N entradas de memoria mais recentes (default: 20, 0 = todas)
#   --dry-run          Alias historico de --raw=false sem efeito de escrita (mantido por
#                      compatibilidade; activate.sh nao escreve mais em memory.md)
#
# Este script e READ-ONLY sobre a memoria dos pods. A memoria so e escrita por
# update_memory.sh, depois que a IA responde. Registrar a tarefa antes da resposta
# enchia memory.md de entradas sem output e dobrava a superficie de conflito no git.
#
# Pods: po, backend, frontend, qa, sec, devops, supervisor

set -e

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"
SHARED_CONTEXT_DIR="$AGENTS_DIR/context/shared"
RUNLOG_DIR="$AGENTS_DIR/.runlog"

# shellcheck source=lib/memory.sh
. "$AGENTS_DIR/lib/memory.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

RAW=false
MEMORY_LIMIT=20

# Chrome (banner, dicas, avisos). Em --raw vai para stderr para nao poluir o prompt.
say() {
    if [ "$RAW" = true ]; then
        echo -e "$@" >&2
    else
        echo -e "$@"
    fi
}

# Conteudo do prompt. Sempre stdout.
emit() {
    echo "$@"
}

# Separadores visuais: ruido em --raw, estrutura no modo copia-e-cola.
sep() {
    if [ "$RAW" = true ]; then
        emit ""
    else
        emit "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        emit ""
    fi
}

# Cabecalho de secao: sem cor em --raw (escapes ANSI viram conteudo no prompt).
section() {
    local title="$1" color="$2"
    if [ "$RAW" = true ]; then
        emit "=== $title ==="
    else
        echo -e "${color}=== $title ===${NC}"
    fi
    emit ""
}

# Parse flags
while [[ "$1" == --* ]]; do
    case "$1" in
        --raw) RAW=true; shift ;;
        --dry-run) shift ;;
        --memory-limit=*) MEMORY_LIMIT="${1#*=}"; shift ;;
        *) echo -e "${RED}Flag desconhecida: $1${NC}" >&2; exit 1 ;;
    esac
done

if ! [[ "$MEMORY_LIMIT" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Erro: --memory-limit precisa ser um inteiro >= 0${NC}" >&2
    exit 1
fi

if [ $# -lt 2 ]; then
    {
        echo -e "${RED}Erro: Argumentos insuficientes${NC}"
        echo ""
        echo "Uso: $0 [--raw] [--memory-limit=N] <pod-name> \"<task>\""
        echo ""
        echo "Pods disponíveis:"
        echo "  po         Product Owner"
        echo "  backend    Backend Developers"
        echo "  frontend   Frontend Developers"
        echo "  qa         Quality Assurance"
        echo "  sec        Security Engineers"
        echo "  devops     DevOps Analysts"
        echo "  supervisor Supervisor (orquestrador)"
        echo ""
        echo "Flags:"
        echo "  --raw              Só o prompt em stdout (para pipe em agente headless)"
        echo "  --memory-limit=N   Últimas N entradas de memória (default: 20, 0 = todas)"
    } >&2
    exit 1
fi

POD_NAME="$1"
TASK="$2"

if ! memory_is_valid_pod "$POD_NAME"; then
    echo -e "${RED}Erro: Pod '$POD_NAME' não é válido${NC}" >&2
    echo "Pods disponíveis: ${MEMORY_VALID_PODS[*]}" >&2
    exit 1
fi

# Supervisor e especial: o PROMPT vive em agents/SUPERVISOR.md, a memoria em pods/supervisor/
if [ "$POD_NAME" = "supervisor" ]; then
    POD_DIR="$PODS_DIR/supervisor"
    PROMPT_FILE="$AGENTS_DIR/SUPERVISOR.md"
    mkdir -p "$POD_DIR"
else
    POD_DIR="$PODS_DIR/$POD_NAME"
    PROMPT_FILE="$POD_DIR/PROMPT.md"
fi

STATE_FILE="$(memory_state_file "$PODS_DIR" "$POD_NAME")"
LOG_DIR="$(memory_log_dir "$PODS_DIR" "$POD_NAME")"

if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED}Erro: PROMPT.md não encontrado para '$POD_NAME'${NC}" >&2
    exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
    if [ "$POD_NAME" = "supervisor" ]; then
        echo "# Supervisor - Memória Persistente" > "$STATE_FILE"
    else
        echo -e "${RED}Erro: memory.md não encontrado para '$POD_NAME'${NC}" >&2
        exit 1
    fi
fi

mkdir -p "$POD_DIR/context" "$LOG_DIR" "$SHARED_CONTEXT_DIR"

get_pod_display_name() {
    case "$POD_NAME" in
        po)         echo "Product Owner" ;;
        qa)         echo "Quality Assurance" ;;
        backend)    echo "Backend Developers" ;;
        frontend)   echo "Frontend Developers" ;;
        sec)        echo "Security Engineers" ;;
        devops)     echo "DevOps Analysts" ;;
        supervisor) echo "Supervisor" ;;
    esac
}

say "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
say "${BLUE}║${NC}  $(get_pod_display_name) Pod Activated"
say "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
say ""
say "${YELLOW}[INFO]${NC} Pod:  $(get_pod_display_name) ($POD_NAME)"
say "${YELLOW}[INFO]${NC} Task: $TASK"
say ""

# ── SYSTEM PROMPT ──────────────────────────────────────────────
sep
section "SYSTEM PROMPT" "$GREEN"
cat "$PROMPT_FILE"
emit ""

# ── SHARED PROJECT CONTEXT ─────────────────────────────────────
if [ -f "$SHARED_CONTEXT_DIR/project.md" ] && [ -s "$SHARED_CONTEXT_DIR/project.md" ]; then
    sep
    section "SHARED PROJECT CONTEXT" "$CYAN"
    cat "$SHARED_CONTEXT_DIR/project.md"
    emit ""
fi

# ── INTER-POD ARTIFACTS ────────────────────────────────────────
ARTIFACTS_SHOWN=false
for artifact_file in "$SHARED_CONTEXT_DIR"/*.md; do
    [ "$artifact_file" = "$SHARED_CONTEXT_DIR/project.md" ] && continue
    if [ -f "$artifact_file" ] && [ -s "$artifact_file" ]; then
        if [ "$ARTIFACTS_SHOWN" = false ]; then
            sep
            section "INTER-POD ARTIFACTS (outputs de outros pods)" "$CYAN"
            ARTIFACTS_SHOWN=true
        fi
        artifact_name=$(basename "$artifact_file" .md)
        emit "--- $artifact_name ---"
        cat "$artifact_file"
        emit ""
    fi
done

# ── MEMORY: ESTADO CURADO ─────────────────────────────────────
sep
section "MEMORY — ESTADO ATUAL DO POD" "$GREEN"
cat "$STATE_FILE"
emit ""

# ── MEMORY: LOG DE ENTRADAS (shards) ──────────────────────────
SHARDS="$(memory_list_shards "$PODS_DIR" "$POD_NAME")"
if [ -n "$SHARDS" ]; then
    SHARD_TOTAL=$(printf '%s\n' "$SHARDS" | grep -c .)
    if [ "$MEMORY_LIMIT" -gt 0 ] && [ "$SHARD_TOTAL" -gt "$MEMORY_LIMIT" ]; then
        SELECTED="$(printf '%s\n' "$SHARDS" | tail -n "$MEMORY_LIMIT")"
        say "${YELLOW}[INFO]${NC} Memória: $MEMORY_LIMIT de $SHARD_TOTAL entradas (--memory-limit=0 para todas)"
    else
        SELECTED="$SHARDS"
        say "${YELLOW}[INFO]${NC} Memória: $SHARD_TOTAL entrada(s)"
    fi

    sep
    section "MEMORY — HISTÓRICO DE DECISÕES" "$GREEN"
    while IFS= read -r shard; do
        [ -n "$shard" ] || continue
        cat "$shard"
        emit ""
    done <<< "$SELECTED"
fi

# ── TASK ──────────────────────────────────────────────────────
sep
section "TASK TO EXECUTE" "$GREEN"
emit "$TASK"
emit ""
sep

# ── RUN LOG ───────────────────────────────────────────────────
# Um arquivo por autor: append concorrente entre devs nunca colide no git.
AUTHOR="$(memory_author)"
mkdir -p "$RUNLOG_DIR"
printf '%s\t%s\t%s\t%s\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$POD_NAME" "$(memory_branch)" "$TASK" \
    >> "$RUNLOG_DIR/$AUTHOR.log"

say "${GREEN}✓ Pod ativado (memória não foi modificada — activate.sh é read-only)${NC}"
say "${YELLOW}[TIP]${NC}  Após receber a resposta da IA, salve o output:"
say "         ${CYAN}./update_memory.sh $POD_NAME \"<resumo das decisões>\"${NC}"
say "${YELLOW}[TIP]${NC}  Headless: ${CYAN}./activate.sh --raw $POD_NAME \"<task>\" | claude -p${NC}"
say ""
