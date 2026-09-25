#!/bin/bash

# update_memory.sh - Salva o output/decisoes da IA na memoria do pod
#
# Uso: ./update_memory.sh [flags] <pod> "<resumo do output>"
#      ./update_memory.sh [flags] --stdin <pod> < resposta.md
#
# Flags:
#   --validate         Avisa se o resumo nao segue o bloco '## MEMORY UPDATE'
#   --strict-validate  Falha se o resumo nao segue o bloco
#   --stdin            Le o resumo de stdin (para pipe de agente headless)
#   --task="<texto>"   Tarefa que originou o output (vai no frontmatter e no nome do arquivo)
#
# Cada chamada cria UM ARQUIVO NOVO em pods/<pod>/memory/. Nunca faz append.
# Append no mesmo arquivo gerava conflito de merge toda vez que dois devs
# tocavam o mesmo pod na mesma sprint.
#
# Exemplo:
#   ./update_memory.sh backend "Implementada API de auth: POST /auth/login retorna JWT RS256 1h."
#   ./activate.sh --raw backend "$T" | claude -p | ./update_memory.sh --stdin --task="$T" backend

set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"
PODS_DIR="$AGENTS_DIR/pods"
LOCKS_DIR="$AGENTS_DIR/.locks"

# shellcheck source=lib/memory.sh
. "$AGENTS_DIR/lib/memory.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
LOCK_HELD=false
LOCK_PATH=""

release_lock() {
    if [ "$LOCK_HELD" = true ] && [ -n "$LOCK_PATH" ] && [ -d "$LOCK_PATH" ]; then
        rmdir "$LOCK_PATH" 2>/dev/null || true
    fi
}

# Escopo do lock: processos na MESMA maquina. Nao serializa devs diferentes —
# entre maquinas quem serializa e o git. Aqui ele so evita que duas chamadas
# simultaneas do mesmo autor disputem o mesmo nome de shard.
acquire_lock() {
    local lock_name="$1"
    local attempts="${LOCK_MAX_ATTEMPTS:-100}"
    local sleep_seconds="${LOCK_SLEEP_SECONDS:-0.1}"

    mkdir -p "$LOCKS_DIR"
    LOCK_PATH="$LOCKS_DIR/$lock_name.lock"

    while ! mkdir "$LOCK_PATH" 2>/dev/null; do
        attempts=$((attempts - 1))
        if [ "$attempts" -le 0 ]; then
            echo -e "${RED}Erro: timeout ao aguardar lock de escrita para '$lock_name'${NC}" >&2
            echo "Tente novamente em alguns segundos." >&2
            exit 1
        fi
        sleep "$sleep_seconds"
    done

    LOCK_HELD=true
    trap release_lock EXIT INT TERM
}

VALIDATE=false
STRICT_VALIDATE=false
FROM_STDIN=false
TASK=""

while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --validate) VALIDATE=true; shift ;;
        --strict-validate) VALIDATE=true; STRICT_VALIDATE=true; shift ;;
        --stdin) FROM_STDIN=true; shift ;;
        --task=*) TASK="${1#*=}"; shift ;;
        *)
            echo -e "${RED}Flag desconhecida: $1${NC}" >&2
            exit 1
            ;;
    esac
done

usage() {
    {
        echo -e "${RED}Erro: Argumentos insuficientes${NC}"
        echo ""
        echo "Uso: $0 [--validate|--strict-validate] [--task=\"<tarefa>\"] <pod> \"<resumo do output da IA>\""
        echo "     $0 [flags] --stdin <pod> < resposta.md"
        echo ""
        echo "Exemplo:"
        echo "  $0 backend \"API de auth implementada: JWT RS256, refresh token, bcrypt 12 rounds\""
        echo "  $0 po \"US-001 a US-005 criadas, MVP = auth + dashboard, Phase2 = billing\""
    } >&2
    exit 1
}

if [ "$FROM_STDIN" = true ]; then
    [ $# -lt 1 ] && usage
    POD_NAME="$1"
    SUMMARY="$(cat)"
    if [ -z "$SUMMARY" ]; then
        echo -e "${RED}Erro: stdin vazio${NC}" >&2
        exit 1
    fi
else
    [ $# -lt 2 ] && usage
    POD_NAME="$1"
    SUMMARY="$2"
fi

if ! memory_is_valid_pod "$POD_NAME"; then
    echo -e "${RED}Pod '$POD_NAME' inválido. Disponíveis: ${MEMORY_VALID_PODS[*]}${NC}" >&2
    exit 1
fi

STATE_FILE="$(memory_state_file "$PODS_DIR" "$POD_NAME")"
if [ ! -f "$STATE_FILE" ]; then
    echo -e "${RED}memory.md não encontrado para '$POD_NAME'${NC}" >&2
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
            echo -e "${RED}Erro: validacao estrita falhou${NC}" >&2
            exit 1
        fi
    fi
fi

AUTHOR="$(memory_author)"
BRANCH="$(memory_branch)"
TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Slug vem da tarefa quando informada; senao da primeira linha util do resumo.
if [ -n "$TASK" ]; then
    SLUG="$(memory_slug "$TASK")"
else
    FIRST_LINE="$(printf '%s\n' "$SUMMARY" | grep -v '^#' | grep -m1 . || true)"
    SLUG="$(memory_slug "${FIRST_LINE:-entrada}")"
fi

acquire_lock "$POD_NAME-memory"
SHARD_PATH="$(memory_new_shard_path "$PODS_DIR" "$POD_NAME" "$AUTHOR" "$SLUG")"

{
    echo "---"
    echo "pod: $POD_NAME"
    echo "author: $AUTHOR"
    echo "branch: $BRANCH"
    echo "date: $TIMESTAMP"
    [ -n "$TASK" ] && echo "task: $TASK"
    echo "---"
    echo ""
    printf '%s\n' "$SUMMARY"
} > "$SHARD_PATH"

echo -e "${GREEN}✓ Entrada salva na memória do pod '$POD_NAME'${NC}"
echo -e "         ${CYAN}${SHARD_PATH#"$AGENTS_DIR/"}${NC}"
echo -e "${YELLOW}[TIP]${NC} Decisão duradoura (schema, endpoint, padrão)? Promova para o estado curado:"
echo -e "         ${CYAN}${STATE_FILE#"$AGENTS_DIR/"}${NC}"
echo -e "${YELLOW}[TIP]${NC} Gerou artefato para outros pods lerem? Salve em context/shared/"
