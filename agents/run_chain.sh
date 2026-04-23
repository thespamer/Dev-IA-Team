#!/bin/bash

# run_chain.sh - Executa um chain file passo a passo, guiando o usuario
#
# Uso: ./run_chain.sh <chain-file>
#
# Formato do chain file (ver exemplos em chains/):
#   name=Nome do Chain
#   step po "Tarefa do PO"
#   parallel backend "Tarefa do backend" | frontend "Tarefa do frontend"
#   step qa "Tarefa do QA"
#
# Linhas com "step":     um pod executa, aguarda confirmacao
# Linhas com "parallel": multiplos pods em paralelo, todos exibidos juntos
# Linhas com #:          comentarios, ignorados

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

extract_task() {
    local quoted="$1"
    local first_char last_char inner escaped=false i ch

    if [ "${#quoted}" -lt 2 ]; then
        return 1
    fi

    first_char="${quoted:0:1}"
    last_char="${quoted: -1}"
    if [ "$first_char" != '"' ] || [ "$last_char" != '"' ]; then
        return 1
    fi

    inner="${quoted:1:${#quoted}-2}"
    for ((i=0; i<${#inner}; i++)); do
        ch="${inner:i:1}"
        if [ "$escaped" = true ]; then
            escaped=false
            continue
        fi
        if [ "$ch" = "\\" ]; then
            escaped=true
            continue
        fi
        if [ "$ch" = '"' ]; then
            return 1
        fi
    done

    printf '%s' "$inner"
    return 0
}

parse_entry() {
    local entry="$1"
    local line_num="$2"
    local pod task_quoted task

    entry="$(trim "$entry")"
    pod="${entry%% *}"

    if [ -z "$pod" ] || [ "$pod" = "$entry" ]; then
        echo -e "${RED}Erro no chain (linha $line_num): entrada invalida: $entry${NC}" >&2
        return 1
    fi

    task_quoted="${entry#"$pod"}"
    task_quoted="$(trim "$task_quoted")"

    if ! task="$(extract_task "$task_quoted")"; then
        echo -e "${RED}Erro no chain (linha $line_num): tarefa deve estar entre aspas duplas: $entry${NC}" >&2
        return 1
    fi

    printf '%s\n%s' "$pod" "$task"
    return 0
}

split_parallel_entries() {
    local input="$1"
    local line_num="$2"
    local in_quotes=false
    local escaped=false
    local i ch current

    current=""

    for ((i=0; i<${#input}; i++)); do
        ch="${input:i:1}"

        if [ "$escaped" = true ]; then
            current+="$ch"
            escaped=false
            continue
        fi

        if [ "$ch" = "\\" ]; then
            current+="$ch"
            escaped=true
            continue
        fi

        if [ "$ch" = '"' ]; then
            if [ "$in_quotes" = true ]; then
                in_quotes=false
            else
                in_quotes=true
            fi
            current+="$ch"
            continue
        fi

        if [ "$ch" = "|" ] && [ "$in_quotes" = false ]; then
            printf '%s\n' "$(trim "$current")"
            current=""
            continue
        fi

        current+="$ch"
    done

    if [ "$in_quotes" = true ]; then
        echo -e "${RED}Erro no chain (linha $line_num): aspas nao fechadas em bloco parallel${NC}" >&2
        return 1
    fi

    printf '%s\n' "$(trim "$current")"
    return 0
}

if [ $# -lt 1 ]; then
    echo -e "${RED}Uso: $0 <chain-file>${NC}"
    echo ""
    echo "Exemplos de chain files disponiveis:"
    for f in "$AGENTS_DIR/chains"/*.chain; do
        [ -f "$f" ] && echo "  $(basename "$f")"
    done
    exit 1
fi

CHAIN_FILE="$1"

if [ ! -f "$CHAIN_FILE" ]; then
    if [ -f "$AGENTS_DIR/chains/$CHAIN_FILE" ]; then
        CHAIN_FILE="$AGENTS_DIR/chains/$CHAIN_FILE"
    else
        echo -e "${RED}Arquivo nao encontrado: $CHAIN_FILE${NC}"
        exit 1
    fi
fi

CHAIN_NAME=$(grep "^name=" "$CHAIN_FILE" | head -1 | sed 's/^name=//')
[ -z "$CHAIN_NAME" ] && CHAIN_NAME="$(basename "$CHAIN_FILE" .chain)"

TOTAL_STEPS=$(grep -c "^step \|^parallel " "$CHAIN_FILE" 2>/dev/null || echo "0")

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Chain Runner — $CHAIN_NAME${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Chain file:  $CHAIN_FILE"
echo -e "  Total steps: ${CYAN}$TOTAL_STEPS${NC}"
echo ""
echo -e "${YELLOW}Como funciona:${NC}"
echo "  1. O script exibe o comando de cada step"
echo "  2. Voce roda o comando no terminal"
echo "  3. Copia o output e cola no AI chat"
echo "  4. Pressiona ENTER para ir ao proximo step"
echo ""
read -p "Pressione ENTER para comecar..." _

STEP_NUM=0
LINE_NUM=0

while IFS= read -r line || [ -n "$line" ]; do
    LINE_NUM=$((LINE_NUM + 1))
    [[ "$line" =~ ^# ]] && continue
    [[ "$line" =~ ^name= ]] && continue
    [[ -z "${line// }" ]] && continue

    if [[ "$line" =~ ^step[[:space:]] ]]; then
        STEP_NUM=$((STEP_NUM + 1))
        rest="${line#step }"
        parsed="$(parse_entry "$rest" "$LINE_NUM")" || exit 1
        pod="${parsed%%$'\n'*}"
        task="${parsed#*$'\n'}"

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}Step $STEP_NUM of $TOTAL_STEPS${NC}"
        echo ""
        echo -e "${YELLOW}Execute no terminal:${NC}"
        echo ""
        echo -e "  ${CYAN}./activate.sh $pod \"$task\"${NC}"
        echo ""
        echo "Depois:"
        echo "  1. Copie o output completo"
        echo "  2. Cole no seu chat de IA"
        echo "  3. Salve o resultado: ./update_memory.sh $pod \"<resumo>\""
        echo ""
        read -p "Pressione ENTER quando estiver pronto para o proximo step..." _

    elif [[ "$line" =~ ^parallel[[:space:]] ]]; then
        STEP_NUM=$((STEP_NUM + 1))
        rest="${line#parallel }"

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}Step $STEP_NUM of $TOTAL_STEPS${NC} ${CYAN}(PARALELO — abra terminais separados)${NC}"
        echo ""

        terminal_num=1
        while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            parsed="$(parse_entry "$entry" "$LINE_NUM")" || exit 1
            pod="${parsed%%$'\n'*}"
            task="${parsed#*$'\n'}"
            echo -e "${YELLOW}Terminal $terminal_num:${NC}"
            echo -e "  ${CYAN}./activate.sh $pod \"$task\"${NC}"
            echo ""
            terminal_num=$((terminal_num + 1))
        done < <(split_parallel_entries "$rest" "$LINE_NUM")

        echo "Depois (para cada terminal):"
        echo "  1. Copie o output completo"
        echo "  2. Cole no seu chat de IA"
        echo "  3. Salve o resultado com ./update_memory.sh <pod> \"<resumo>\""
        echo ""
        read -p "Pressione ENTER quando TODOS os terminais paralelos estiverem concluidos..." _
    else
        echo -e "${RED}Erro no chain (linha $LINE_NUM): comando desconhecido: $line${NC}"
        exit 1
    fi

done < "$CHAIN_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✓ Chain '$CHAIN_NAME' concluido! ($TOTAL_STEPS steps)${NC}"
echo ""
echo -e "${YELLOW}Proximos passos sugeridos:${NC}"
echo "  ./status.sh               — ver historico de todos os pods"
echo "  ./status.sh <pod>         — ver historico detalhado de um pod"
echo "  ./archive_memory.sh       — arquivar entradas antigas se necessario"
echo ""
