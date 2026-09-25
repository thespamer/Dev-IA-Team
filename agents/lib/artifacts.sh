#!/bin/bash

# lib/artifacts.sh - Selecao de artefatos inter-pod via manifesto
#
# Antes, activate.sh dava 'cat' em todo context/shared/*.md para todo pod. Com
# uma squad produzindo artefatos a cada sprint, o prompt crescia sem teto e cada
# pod recebia material que nao usa (devops lendo user_stories inteiro, etc).
#
# Agora cada pod declara o que le em pods/<pod>/reads.txt:
#
#   # comentario
#   api_spec.md
#   user_stories.md
#
# Regras:
#   - uma entrada por linha, nome de arquivo simples (sem diretorio)
#   - '#' inicia comentario; linhas vazias ignoradas
#   - a linha '*' sozinha volta ao comportamento antigo (le tudo)
#   - arquivo listado que ainda nao existe e ignorado em silencio: e normal
#     nenhum pod ter produzido aquele artefato ainda
#   - sem reads.txt, o pod cai no comportamento antigo (le tudo)
#
# project.md nao entra aqui: e o contexto compartilhado do projeto, sempre
# carregado para todos os pods, em secao propria.

ARTIFACTS_MANIFEST_NAME="reads.txt"

artifacts_manifest_path() {
    local pods_dir="$1" pod="$2"
    echo "$pods_dir/$pod/$ARTIFACTS_MANIFEST_NAME"
}

# Todo *.md de context/shared/ menos project.md, em ordem alfabetica.
# Sempre retorna 0: "nenhum artefato" e um resultado valido, nao erro. Quem
# chama roda com 'set -e' e morreria no meio da montagem do prompt.
artifacts_all() {
    local shared_dir="$1" file
    for file in "$shared_dir"/*.md; do
        [ -f "$file" ] && [ -s "$file" ] || continue
        [ "$(basename "$file")" = "project.md" ] && continue
        echo "$file"
    done
    return 0
}

# Uma entrada de manifesto so pode nomear um arquivo dentro de context/shared/.
# Sem essa checagem, uma linha '../../../.ssh/id_rsa' num PR faria activate.sh
# despejar o arquivo no prompt enviado para a IA.
artifacts_entry_is_safe() {
    local entry="$1"
    case "$entry" in
        */*|..|.|"") return 1 ;;
    esac
    [[ "$entry" == *.md ]]
}

# Artefatos que este pod deve receber, na ordem declarada.
artifacts_for_pod() {
    local pods_dir="$1" shared_dir="$2" pod="$3"
    local manifest entry path seen=""

    manifest="$(artifacts_manifest_path "$pods_dir" "$pod")"

    if [ ! -f "$manifest" ]; then
        artifacts_all "$shared_dir"
        return 0
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        entry="${line%%#*}"
        entry="$(echo "$entry" | tr -d '[:space:]')"
        [ -z "$entry" ] && continue

        if [ "$entry" = "*" ]; then
            artifacts_all "$shared_dir"
            return 0
        fi

        if ! artifacts_entry_is_safe "$entry"; then
            echo "artifacts: entrada invalida em $manifest: '$entry' (esperado: nome.md sem diretorio)" >&2
            continue
        fi

        # Dedupe: manifesto escrito a mao repete entrada com facilidade.
        case "$seen" in
            *"|$entry|"*) continue ;;
        esac
        seen="$seen|$entry|"

        path="$shared_dir/$entry"
        if [ -f "$path" ] && [ -s "$path" ]; then
            echo "$path"
        fi
    done < "$manifest"

    return 0
}

# Entradas do manifesto que ainda nao existem em context/shared/.
# Nao e erro — serve para doctor.sh mostrar o que a squad ainda nao produziu.
artifacts_missing_for_pod() {
    local pods_dir="$1" shared_dir="$2" pod="$3"
    local manifest entry

    manifest="$(artifacts_manifest_path "$pods_dir" "$pod")"
    [ -f "$manifest" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        entry="${line%%#*}"
        entry="$(echo "$entry" | tr -d '[:space:]')"
        [ -z "$entry" ] && continue
        [ "$entry" = "*" ] && continue
        artifacts_entry_is_safe "$entry" || continue
        [ -f "$shared_dir/$entry" ] || echo "$entry"
    done < "$manifest"

    return 0
}
