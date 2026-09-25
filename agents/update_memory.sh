#!/bin/bash

# update_memory.sh - Salva o output/decisoes da IA na memoria do pod
#
# Uso: ./update_memory.sh [flags] <pod> "<resumo do output>"
#      ./update_memory.sh [flags] --stdin <pod> < resposta.md
#
# Flags:
#   --stdin            Le o resumo de stdin (para pipe de agente headless)
#   --task="<texto>"   Tarefa que originou o output (frontmatter e nome do arquivo)
#   --no-contract      Grava sem exigir o bloco '## MEMORY UPDATE'. A entrada fica
#                      marcada 'contract: unverified' no frontmatter, para auditoria.
#   --validate         Aceita por compatibilidade; validar ja e o padrao
#   --strict-validate  Idem
#
# O contrato de memoria e exigido POR PADRAO. O bloco '## MEMORY UPDATE' e
# extraido da resposta da IA e so ele e persistido — memoria guarda decisao, nao
# as 400 linhas de resposta.
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
# shellcheck source=lib/contract.sh
. "$AGENTS_DIR/lib/contract.sh"

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

ENFORCE_CONTRACT=true
FROM_STDIN=false
TASK=""

while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --no-contract) ENFORCE_CONTRACT=false; shift ;;
        --stdin) FROM_STDIN=true; shift ;;
        --task=*) TASK="${1#*=}"; shift ;;
        # Validar passou a ser o padrao; as flags antigas seguem aceitas para nao
        # quebrar scripts e chains existentes.
        --validate|--strict-validate) shift ;;
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
        echo "Uso: $0 [--no-contract] [--task=\"<tarefa>\"] <pod> \"<output da IA>\""
        echo "     $0 [flags] --stdin <pod> < resposta.md"
        echo ""
        echo "O output precisa conter o bloco '## MEMORY UPDATE' com pelo menos 3"
        echo "bullets de conteudo real. Use --no-contract para gravar sem validar."
        echo ""
        echo "Exemplo:"
        echo "  $0 backend \"## MEMORY UPDATE"
        echo "  - POST /auth/login retorna JWT RS256, expiracao 1h"
        echo "  - Schema users criado com bcrypt rounds=12"
        echo "  - Refresh token com rotacao a cada uso\""
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

if [ "$ENFORCE_CONTRACT" = true ]; then
    # A entrada pode ser a resposta inteira da IA. Recorta o bloco; se nao houver
    # heading, valida o texto cru para o erro apontar o que de fato falta.
    BLOCK="$(printf '%s\n' "$SUMMARY" | contract_extract_block)"
    [ -n "$BLOCK" ] || BLOCK="$SUMMARY"

    if ! contract_validate "$BLOCK"; then
        echo -e "${RED}Erro: contrato de memoria nao cumprido — nada foi gravado${NC}" >&2
        contract_explain_failure "$POD_NAME"
        exit 1
    fi

    SUMMARY="$BLOCK"
    CONTRACT_STATUS="verified"
    echo -e "${GREEN}✓ Contrato de memória cumprido${NC}"
else
    CONTRACT_STATUS="unverified"
    echo -e "${YELLOW}[WARN]${NC} Gravando sem validar o contrato (--no-contract)"
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
    echo "contract: $CONTRACT_STATUS"
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
