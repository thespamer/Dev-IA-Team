#!/bin/bash

# update_memory.sh - Salva o output/decisões da IA na memória do pod
# Uso: ./update_memory.sh <pod> "<resumo do output>"
#
# Exemplo:
#   ./update_memory.sh backend "Implementada API de auth: POST /auth/login retorna JWT RS256 1h.
#   Schema users criado com bcrypt rounds=12. AuthService com register/login/logout."

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo -e "${RED}Erro: Argumentos insuficientes${NC}"
    echo ""
    echo "Uso: $0 <pod> \"<resumo do output da IA>\""
    echo ""
    echo "Exemplo:"
    echo "  $0 backend \"API de auth implementada: JWT RS256, refresh token, bcrypt 12 rounds\""
    echo "  $0 po \"US-001 a US-005 criadas, MVP = auth + dashboard, Phase2 = billing\""
    exit 1
fi

POD_NAME="$1"
SUMMARY="$2"

VALID_PODS=("po" "qa" "backend" "frontend" "sec" "devops" "supervisor")
if [[ ! " ${VALID_PODS[@]} " =~ " ${POD_NAME} " ]]; then
    echo -e "${RED}Pod '$POD_NAME' inválido. Disponíveis: ${VALID_PODS[*]}${NC}"
    exit 1
fi

if [ "$POD_NAME" = "supervisor" ]; then
    MEMORY_FILE="$PODS_DIR/supervisor/memory.md"
else
    MEMORY_FILE="$PODS_DIR/$POD_NAME/memory.md"
fi

if [ ! -f "$MEMORY_FILE" ]; then
    echo -e "${RED}memory.md não encontrado para '$POD_NAME'${NC}"
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
{
    echo "### Output salvo em $TIMESTAMP"
    echo "$SUMMARY"
    echo ""
} >> "$MEMORY_FILE"

echo -e "${GREEN}✓ Output salvo na memória do pod '$POD_NAME'${NC}"
echo -e "${YELLOW}[TIP]${NC} Se gerou artefatos para outros pods lerem, salve em context/shared/"
echo "       Exemplo: cp context/api_spec.md ../context/shared/api_spec.md"
