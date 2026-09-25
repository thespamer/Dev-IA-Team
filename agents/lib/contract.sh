#!/bin/bash

# lib/contract.sh - Contrato do bloco '## MEMORY UPDATE'
#
# O PROMPT.md de todo pod ja exige que a IA termine a resposta com:
#
#   ## MEMORY UPDATE
#   - decisao 1
#   - decisao 2
#   - decisao 3
#
# O que faltava era o lado do script. Antes, o resumo era digitado a mao pelo
# humano depois de ler 400 linhas de resposta, e a validacao era opt-in
# (--validate). Resumo redigitado por humano cansado e onde a memoria apodrece —
# e com N devs apodrece N vezes mais rapido.
#
# Agora: o bloco e extraido da resposta da IA e validado por padrao.

CONTRACT_HEADING="## MEMORY UPDATE"
CONTRACT_MIN_BULLETS=3

# Extrai o bloco da resposta completa da IA: do heading ate o proximo '## ' ou
# o fim. Linhas de cerca de codigo (```) saem, porque a IA costuma envolver o
# bloco em fence e a cerca de fechamento cairia dentro do recorte.
contract_extract_block() {
    awk '
        /^## MEMORY UPDATE[[:space:]]*$/ { inside = 1; print; next }
        inside && /^## / { exit }
        inside && /^[[:space:]]*```/ { next }
        inside { print }
    '
}

# Bullets que carregam conteudo real. Um bullet inteiramente entre colchetes e
# o placeholder do template do PROMPT.md ("- [Endpoints definidos: ...]"): se
# persistido, a memoria guarda o molde em vez da decisao.
contract_count_real_bullets() {
    awk '
        /^-[[:space:]]+/ {
            line = $0
            sub(/^-[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            if (line ~ /^\[.*\]$/) next      # placeholder do template
            if (length(line) < 3) next       # bullet vazio ou simbolo solto
            count++
        }
        END { print count + 0 }
    '
}

# 0 se o texto cumpre o contrato. Motivo em stderr quando nao cumpre.
contract_validate() {
    local text="$1"
    local bullets

    if [[ "$text" != *"$CONTRACT_HEADING"* ]]; then
        echo "contrato: bloco '$CONTRACT_HEADING' ausente" >&2
        return 1
    fi

    bullets="$(printf '%s\n' "$text" | contract_count_real_bullets)"
    if [ "$bullets" -lt "$CONTRACT_MIN_BULLETS" ]; then
        echo "contrato: $bullets bullet(s) com conteudo real, minimo $CONTRACT_MIN_BULLETS" >&2
        echo "contrato: bullets inteiramente entre colchetes sao placeholder do template e nao contam" >&2
        return 1
    fi

    return 0
}

# Mensagem de erro acionavel. Um 'exit 1' seco faz a squad abandonar a
# ferramenta; o dev precisa saber o que fazer agora.
contract_explain_failure() {
    local pod="$1"
    cat >&2 <<MSG

O output nao cumpre o contrato de memoria. Caminhos, em ordem de preferencia:

  1. Peca o bloco a IA. Todo PROMPT.md ja exige que a resposta termine com:

       ## MEMORY UPDATE
       - <decisao concreta 1>
       - <decisao concreta 2>
       - <decisao concreta 3>

     Se a IA nao emitiu, responda no chat: "faltou o bloco MEMORY UPDATE".

  2. Escreva os bullets voce mesmo, com conteudo real — nao o molde entre
     colchetes que aparece no PROMPT.md.

  3. Gravar sem validar (a entrada fica marcada 'contract: unverified' no
     frontmatter, para dar para auditar depois):

       ./update_memory.sh --no-contract $pod "<resumo>"

MSG
}
