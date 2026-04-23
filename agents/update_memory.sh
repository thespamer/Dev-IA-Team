#!/bin/bash

# update_memory.sh - Salva o output/decisoes da IA na memoria do pod
# Uso: ./update_memory.sh [--validate|--strict-validate] <pod> "<resumo do output>"
#
# Exemplo:
#   ./update_memory.sh backend "Implementada API de auth: POST /auth/login retorna JWT RS256 1h.
#   Schema users criado com bcrypt rounds=12. AuthService com register/login/logout."

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"
LOCKS_DIR="$AGENTS_DIR/.locks"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
LOCK_HELD=false
LOCK_PATH=""

release_lock() {
    if [ "$LOCK_HELD" = true ] && [ -n "$LOCK_PATH" ] && [ -d "$LOCK_PATH" ]; then
        rmdir "$LOCK_PATH" 2>/dev/null || true
    fi
}

acquire_lock() {
    local lock_name="$1"
    local attempts="${LOCK_MAX_ATTEMPTS:-100}"
    local sleep_seconds="${LOCK_SLEEP_SECONDS:-0.1}"

    mkdir -p "$LOCKS_DIR"
    LOCK_PATH="$LOCKS_DIR/$lock_name.lock"

    while ! mkdir "$LOCK_PATH" 2>/dev/null; do
        attempts=$((attempts - 1))
        if [ "$attempts" -le 0 ]; then
            echo -e "${RED}Erro: timeout ao aguardar lock de escrita para '$lock_name'${NC}"
            echo "Tente novamente em alguns segundos."
            exit 1
        fi
        sleep "$sleep_seconds"
    done

    LOCK_HELD=true
    trap release_lock EXIT INT TERM
}

VALIDATE=false
STRICT_VALIDATE=false

while [[ "$1" == --* ]]; do
    case "$1" in
        --validate) VALIDATE=true; shift ;;
        --strict-validate) VALIDATE=true; STRICT_VALIDATE=true; shift ;;
        *)
            echo -e "${RED}Flag desconhecida: $1${NC}"
            exit 1
            ;;
    esac
done

if [ $# -lt 2 ]; then
    echo -e "${RED}Erro: Argumentos insuficientes${NC}"
    echo ""
    echo "Uso: $0 [--validate|--strict-validate] <pod> \"<resumo do output da IA>\""
    echo ""
    echo "Exemplo:"
    echo "  $0 backend \"API de auth implementada: JWT RS256, refresh token, bcrypt 12 rounds\""
    echo "  $0 po \"US-001 a US-005 criadas, MVP = auth + dashboard, Phase2 = billing\""
    echo "  $0 --validate backend \"## MEMORY UPDATE\n- item 1\n- item 2\n- item 3\""
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

validate_memory_update_block() {
    local text="$1"
    local bullet_count=0

    if [[ "$text" != *"## MEMORY UPDATE"* ]]; then
        return 1
    fi

    while IFS= read -r line; do
        if [[ "$line" =~ ^-[[:space:]]+.+ ]]; then
            bullet_count=$((bullet_count + 1))
        fi
    done <<< "$text"

    [ "$bullet_count" -ge 3 ]
}

if [ "$VALIDATE" = true ]; then
    if validate_memory_update_block "$SUMMARY"; then
        echo -e "${GREEN}✓ Formato MEMORY UPDATE validado${NC}"
    else
        echo -e "${YELLOW}[WARN]${NC} Resumo nao parece seguir o bloco '## MEMORY UPDATE' com pelo menos 3 bullets"
        if [ "$STRICT_VALIDATE" = true ]; then
            echo -e "${RED}Erro: validacao estrita falhou${NC}"
            exit 1
        fi
    fi
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
acquire_lock "$POD_NAME-memory"
{
    echo "### Output salvo em $TIMESTAMP"
    echo "$SUMMARY"
    echo ""
} >> "$MEMORY_FILE"

echo -e "${GREEN}✓ Output salvo na memória do pod '$POD_NAME'${NC}"
echo -e "${YELLOW}[TIP]${NC} Se gerou artefatos para outros pods lerem, salve em context/shared/"
echo "       Exemplo: cp context/api_spec.md ../context/shared/api_spec.md"
