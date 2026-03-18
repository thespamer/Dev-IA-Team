#!/bin/bash

# activate.sh - Script para ativar um pod especializado
# Uso: ./activate.sh <pod-name> "<task>"
#
# pods disponíveis: po, qa, backend, frontend, sec, devops

set -e

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validar argumentos
if [ $# -lt 2 ]; then
    echo -e "${RED}Erro: Argumentos insuficientes${NC}"
    echo "Uso: $0 <pod-name> \"<task>\""
    echo ""
    echo "Pods disponíveis:"
    echo "  - po       : Product Owner"
    echo "  - qa       : Quality Assurance"
    echo "  - backend  : Backend Developers"
    echo "  - frontend : Frontend Developers"
    echo "  - sec      : Security Engineers"
    echo "  - devops   : DevOps Analysts"
    exit 1
fi

POD_NAME="$1"
TASK="$2"

# Validar pod
VALID_PODS=("po" "qa" "backend" "frontend" "sec" "devops")
if [[ ! " ${VALID_PODS[@]} " =~ " ${POD_NAME} " ]]; then
    echo -e "${RED}Erro: Pod '$POD_NAME' não é válido${NC}"
    echo "Pods disponíveis: ${VALID_PODS[*]}"
    exit 1
fi

POD_DIR="$PODS_DIR/$POD_NAME"

# Validar existência do pod
if [ ! -d "$POD_DIR" ]; then
    echo -e "${RED}Erro: Diretório do pod '$POD_NAME' não encontrado${NC}"
    exit 1
fi

# Validar arquivos obrigatórios
if [ ! -f "$POD_DIR/PROMPT.md" ]; then
    echo -e "${RED}Erro: PROMPT.md não encontrado para o pod '$POD_NAME'${NC}"
    exit 1
fi

if [ ! -f "$POD_DIR/memory.md" ]; then
    echo -e "${RED}Erro: memory.md não encontrado para o pod '$POD_NAME'${NC}"
    exit 1
fi

# Função para ler PROMPT.md
read_prompt() {
    cat "$POD_DIR/PROMPT.md"
}

# Função para ler memory.md
read_memory() {
    cat "$POD_DIR/memory.md"
}

# Função para obter pod display name
get_pod_display_name() {
    case "$POD_NAME" in
        po) echo "Product Owner" ;;
        qa) echo "Quality Assurance" ;;
        backend) echo "Backend Developers" ;;
        frontend) echo "Frontend Developers" ;;
        sec) echo "Security Engineers" ;;
        devops) echo "DevOps Analysts" ;;
    esac
}

# Banner
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  $(get_pod_display_name) Pod Activated"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Mostrar informações do pod
echo -e "${YELLOW}[INFO]${NC} Pod: $(get_pod_display_name) ($POD_NAME)"
echo -e "${YELLOW}[INFO]${NC} Task: $TASK"
echo ""

# Separador
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Mostrar PROMPT do pod
echo -e "${GREEN}=== SYSTEM PROMPT ===${NC}"
echo ""
read_prompt
echo ""

# Separador
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Mostrar memória do pod
echo -e "${GREEN}=== MEMORY (Contexto Persistente) ===${NC}"
echo ""
read_memory
echo ""

# Separador
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Instruções para o agente
echo -e "${GREEN}=== TASK TO EXECUTE ===${NC}"
echo ""
echo "$TASK"
echo ""

# Separador
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Atualizar memory.md com a tarefa (append)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "" >> "$POD_DIR/memory.md"
echo "## Tarefa Executada em $TIMESTAMP" >> "$POD_DIR/memory.md"
echo "**Task**: $TASK" >> "$POD_DIR/memory.md"
echo "" >> "$POD_DIR/memory.md"

echo -e "${GREEN}✓ Pod ativado com sucesso${NC}"
echo -e "${YELLOW}[NOTE]${NC} A memória do pod foi atualizada com a tarefa"
echo ""
