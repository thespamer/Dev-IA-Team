#!/bin/bash

# run_chain.sh - Executa um chain file passo a passo, guiando o usuário
#
# Uso: ./run_chain.sh <chain-file>
#
# Formato do chain file (ver exemplos em chains/):
#   name=Nome do Chain
#   step po "Tarefa do PO"
#   parallel backend "Tarefa do backend" | frontend "Tarefa do frontend"
#   step qa "Tarefa do QA"
#
# Linhas com "step":     um pod executa, aguarda confirmação
# Linhas com "parallel": múltiplos pods em paralelo, todos exibidos juntos
# Linhas com #:          comentários, ignorados

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

if [ $# -lt 1 ]; then
    echo -e "${RED}Uso: $0 <chain-file>${NC}"
    echo ""
    echo "Exemplos de chain files disponíveis:"
    for f in "$AGENTS_DIR/chains"/*.chain; do
        [ -f "$f" ] && echo "  $(basename "$f")"
    done
    exit 1
fi

CHAIN_FILE="$1"

if [ ! -f "$CHAIN_FILE" ]; then
    # Try chains/ directory
    if [ -f "$AGENTS_DIR/chains/$CHAIN_FILE" ]; then
        CHAIN_FILE="$AGENTS_DIR/chains/$CHAIN_FILE"
    else
        echo -e "${RED}Arquivo não encontrado: $CHAIN_FILE${NC}"
        exit 1
    fi
fi

# Parse name
CHAIN_NAME=$(grep "^name=" "$CHAIN_FILE" | head -1 | sed 's/^name=//')
[ -z "$CHAIN_NAME" ] && CHAIN_NAME="$(basename "$CHAIN_FILE" .chain)"

# Count steps (non-comment, non-name lines)
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
echo "  2. Você roda o comando no terminal"
echo "  3. Copia o output e cola no AI chat"
echo "  4. Pressiona ENTER para ir ao próximo step"
echo ""
read -p "Pressione ENTER para começar..." _

STEP_NUM=0

while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and name line
    [[ "$line" =~ ^# ]] && continue
    [[ "$line" =~ ^name= ]] && continue
    [[ -z "${line// }" ]] && continue

    # Detect step type
    if [[ "$line" =~ ^step\ ]]; then
        STEP_NUM=$((STEP_NUM + 1))
        # Parse: step pod "task"
        rest="${line#step }"
        pod=$(echo "$rest" | awk '{print $1}')
        task=$(echo "$rest" | sed "s/^$pod //" | sed 's/^"\(.*\)"$/\1/')

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
        read -p "Pressione ENTER quando estiver pronto para o próximo step..." _

    elif [[ "$line" =~ ^parallel\ ]]; then
        STEP_NUM=$((STEP_NUM + 1))
        # Parse: parallel pod1 "task1" | pod2 "task2" | ...
        rest="${line#parallel }"

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "${GREEN}Step $STEP_NUM of $TOTAL_STEPS${NC} ${CYAN}(PARALELO — abra terminais separados)${NC}"
        echo ""

        terminal_num=1
        IFS='|' read -ra PARALLEL_PODS <<< "$rest"
        for entry in "${PARALLEL_PODS[@]}"; do
            entry=$(echo "$entry" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            pod=$(echo "$entry" | awk '{print $1}')
            task=$(echo "$entry" | sed "s/^$pod //" | sed 's/^"\(.*\)"$/\1/')
            echo -e "${YELLOW}Terminal $terminal_num:${NC}"
            echo -e "  ${CYAN}./activate.sh $pod \"$task\"${NC}"
            echo ""
            terminal_num=$((terminal_num + 1))
        done

        echo "Depois (para cada terminal):"
        echo "  1. Copie o output completo"
        echo "  2. Cole no seu chat de IA"
        echo "  3. Salve o resultado com ./update_memory.sh <pod> \"<resumo>\""
        echo ""
        read -p "Pressione ENTER quando TODOS os terminais paralelos estiverem concluídos..." _
    fi

done < "$CHAIN_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}✓ Chain '$CHAIN_NAME' concluído! ($TOTAL_STEPS steps)${NC}"
echo ""
echo -e "${YELLOW}Próximos passos sugeridos:${NC}"
echo "  ./status.sh               — ver histórico de todos os pods"
echo "  ./status.sh <pod>         — ver histórico detalhado de um pod"
echo "  ./archive_memory.sh       — arquivar entradas antigas se necessário"
echo ""
