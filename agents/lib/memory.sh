#!/bin/bash

# lib/memory.sh - Helpers de memoria em shards (um arquivo por entrada)
#
# Layout:
#   pods/<pod>/memory.md          Estado curado do pod (tabelas, decisoes). Editado a mao.
#   pods/<pod>/memory/*.md        Log de entradas. Um arquivo por entrada, nunca editado.
#   pods/<pod>/memory/archive/    Entradas antigas movidas por archive_memory.sh
#
# Por que shards: append no mesmo arquivo gera conflito de merge sempre que dois
# devs tocam o mesmo pod. Arquivo novo por entrada elimina a classe de conflito.

MEMORY_VALID_PODS=("po" "qa" "backend" "frontend" "sec" "devops" "supervisor")

memory_is_valid_pod() {
    local pod="$1"
    local candidate
    for candidate in "${MEMORY_VALID_PODS[@]}"; do
        [ "$candidate" = "$pod" ] && return 0
    done
    return 1
}

memory_pod_dir() {
    local pods_dir="$1" pod="$2"
    echo "$pods_dir/$pod"
}

# Estado curado do pod — lido em toda ativacao, editado a mao e revisado em PR.
memory_state_file() {
    local pods_dir="$1" pod="$2"
    echo "$pods_dir/$pod/memory.md"
}

# Diretorio de log em shards.
memory_log_dir() {
    local pods_dir="$1" pod="$2"
    echo "$pods_dir/$pod/memory"
}

memory_archive_dir() {
    local pods_dir="$1" pod="$2"
    echo "$pods_dir/$pod/memory/archive"
}

# Lista shards ativos em ordem cronologica (nome comeca com timestamp UTC).
# archive/ fica de fora por nao ser -maxdepth 1.
memory_list_shards() {
    local pods_dir="$1" pod="$2"
    local log_dir
    log_dir="$(memory_log_dir "$pods_dir" "$pod")"
    [ -d "$log_dir" ] || return 0
    find "$log_dir" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort
}

memory_count_shards() {
    local pods_dir="$1" pod="$2"
    memory_list_shards "$pods_dir" "$pod" | grep -c . || true
}

# Identidade do autor da entrada. Sem isso nao da para saber quem decidiu o que.
memory_author() {
    local author="${DEVIA_AUTHOR:-}"
    if [ -z "$author" ]; then
        author="$(git config user.email 2>/dev/null | cut -d@ -f1)"
    fi
    if [ -z "$author" ]; then
        author="${USER:-anon}"
    fi
    memory_slug "$author"
}

memory_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "sem-branch"
}

# Normaliza texto livre para uso em nome de arquivo.
memory_slug() {
    local text="$1"
    echo "$text" \
        | tr '[:upper:]' '[:lower:]' \
        | tr ' _/' '-' \
        | tr -cd 'a-z0-9-' \
        | sed -e 's/--*/-/g' -e 's/^-//' -e 's/-$//' \
        | cut -c1-40
}

# Caminho novo e livre para uma entrada. Sufixo numerico resolve colisao de
# mesmo autor + mesmo slug no mesmo segundo.
memory_new_shard_path() {
    local pods_dir="$1" pod="$2" author="$3" slug="$4"
    local log_dir stamp base candidate suffix

    log_dir="$(memory_log_dir "$pods_dir" "$pod")"
    mkdir -p "$log_dir"

    stamp="$(date -u '+%Y%m%dT%H%M%SZ')"
    [ -z "$slug" ] && slug="entrada"
    base="$log_dir/$stamp-$author-$slug"

    candidate="$base.md"
    suffix=1
    while [ -e "$candidate" ]; do
        candidate="$base-$suffix.md"
        suffix=$((suffix + 1))
    done

    echo "$candidate"
}

# Extrai um campo do frontmatter YAML simples do shard.
memory_shard_field() {
    local shard="$1" field="$2"
    sed -n "/^---$/,/^---$/p" "$shard" 2>/dev/null \
        | sed -n "s/^$field: //p" \
        | head -1
}

# Corpo do shard, sem o frontmatter YAML.
# Um unico passe: dois 'sed 1,/^---$/d' encadeados apagariam o corpo inteiro
# quando nao sobra um terceiro '---' no arquivo.
memory_shard_body() {
    awk '
        NR == 1 && $0 == "---" { in_fm = 1; next }
        in_fm == 1 && $0 == "---" { in_fm = 0; next }
        in_fm == 1 { next }
        { print }
    ' "$1"
}
