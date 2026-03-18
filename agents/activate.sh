#!/bin/bash

# activate.sh - Ativa um pod especializado com contexto completo
# Uso: ./activate.sh [--dry-run] <pod-name> "<task>"
#
# Flags:
#   --dry-run   Exibe contexto sem atualizar memory.md
#
# Pods: po, backend, frontend, qa, sec, devops, supervisor

set -e

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"
SHARED_CONTEXT_DIR="$AGENTS_DIR/context/shared"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DRY_RUN=false

# Parse flags
while [[ "$1" == --* ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        *) echo -e "${RED}Flag desconhecida: $1${NC}"; exit 1 ;;
    esac
done

if [ $# -lt 2 ]; then
    echo -e "${RED}Erro: Argumentos insuficientes${NC}"
    echo ""
    echo "Uso: $0 [--dry-run] <pod-name> \"<task>\""
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
    echo "  --dry-run  Mostra contexto sem atualizar memory.md"
    exit 1
fi

POD_NAME="$1"
TASK="$2"

VALID_PODS=("po" "qa" "backend" "frontend" "sec" "devops" "supervisor")
if [[ ! " ${VALID_PODS[@]} " =~ " ${POD_NAME} " ]]; then
    echo -e "${RED}Erro: Pod '$POD_NAME' não é válido${NC}"
    echo "Pods disponíveis: ${VALID_PODS[*]}"
    exit 1
fi

# Supervisor é especial: vive em agents/ com sua própria pasta de memória
if [ "$POD_NAME" = "supervisor" ]; then
    POD_DIR="$AGENTS_DIR"
    PROMPT_FILE="$AGENTS_DIR/SUPERVISOR.md"
    MEMORY_FILE="$PODS_DIR/supervisor/memory.md"
    mkdir -p "$PODS_DIR/supervisor"
    [ ! -f "$MEMORY_FILE" ] && echo "# Supervisor - Memória Persistente" > "$MEMORY_FILE"
else
    POD_DIR="$PODS_DIR/$POD_NAME"
    PROMPT_FILE="$POD_DIR/PROMPT.md"
    MEMORY_FILE="$POD_DIR/memory.md"
fi

if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED}Erro: PROMPT.md não encontrado para '$POD_NAME'${NC}"
    exit 1
fi

if [ ! -f "$MEMORY_FILE" ]; then
    echo -e "${RED}Erro: memory.md não encontrado para '$POD_NAME'${NC}"
    exit 1
fi

# Garante que context/ e context/shared/ existem
if [ "$POD_NAME" != "supervisor" ]; then
    mkdir -p "$POD_DIR/context"
fi
mkdir -p "$SHARED_CONTEXT_DIR"

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

DRY_LABEL=""
[ "$DRY_RUN" = true ] && DRY_LABEL=" ${YELLOW}[DRY RUN]${NC}"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  $(get_pod_display_name) Pod Activated${DRY_LABEL}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}[INFO]${NC} Pod:  $(get_pod_display_name) ($POD_NAME)"
echo -e "${YELLOW}[INFO]${NC} Task: $TASK"
[ "$DRY_RUN" = true ] && echo -e "${YELLOW}[DRY RUN]${NC} memory.md NÃO será atualizado"
echo ""

# ── SYSTEM PROMPT ──────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}=== SYSTEM PROMPT ===${NC}"
echo ""
cat "$PROMPT_FILE"
echo ""

# ── SHARED PROJECT CONTEXT ─────────────────────────────────────
if [ -f "$SHARED_CONTEXT_DIR/project.md" ] && [ -s "$SHARED_CONTEXT_DIR/project.md" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${CYAN}=== SHARED PROJECT CONTEXT ===${NC}"
    echo ""
    cat "$SHARED_CONTEXT_DIR/project.md"
    echo ""
fi

# ── INTER-POD ARTIFACTS ────────────────────────────────────────
ARTIFACTS_SHOWN=false
for artifact_file in "$SHARED_CONTEXT_DIR"/*.md; do
    [ "$artifact_file" = "$SHARED_CONTEXT_DIR/project.md" ] && continue
    if [ -f "$artifact_file" ] && [ -s "$artifact_file" ]; then
        if [ "$ARTIFACTS_SHOWN" = false ]; then
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
            echo -e "${CYAN}=== INTER-POD ARTIFACTS (outputs de outros pods) ===${NC}"
            echo ""
            ARTIFACTS_SHOWN=true
        fi
        artifact_name=$(basename "$artifact_file" .md)
        echo -e "${CYAN}--- $artifact_name ---${NC}"
        cat "$artifact_file"
        echo ""
    fi
done

# ── MEMORY ────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}=== MEMORY (Contexto Persistente) ===${NC}"
echo ""
cat "$MEMORY_FILE"
echo ""

# ── TASK ──────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}=== TASK TO EXECUTE ===${NC}"
echo ""
echo "$TASK"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── UPDATE MEMORY ─────────────────────────────────────────────
if [ "$DRY_RUN" = false ]; then
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    {
        echo ""
        echo "## Tarefa Executada em $TIMESTAMP"
        echo "**Task**: $TASK"
        echo ""
    } >> "$MEMORY_FILE"

    echo -e "${GREEN}✓ Pod ativado com sucesso${NC}"
    echo -e "${YELLOW}[NOTE]${NC} memory.md atualizado com a tarefa"
    echo -e "${YELLOW}[TIP]${NC}  Após receber a resposta da IA, salve o output:"
    echo -e "         ${CYAN}./update_memory.sh $POD_NAME \"<resumo das decisões>\"${NC}"
else
    echo -e "${YELLOW}[DRY RUN]${NC} memory.md NÃO foi atualizado"
fi
echo ""
