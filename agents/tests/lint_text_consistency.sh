#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PODS_DIR="$ROOT_DIR/agents/pods"

echo "[text-lint] Checking pod prompts"

for prompt in "$PODS_DIR"/*/PROMPT.md; do
    [ -f "$prompt" ] || continue

    if grep -q "^## Skills$" "$prompt"; then
        echo "Found legacy heading '## Skills' in: $prompt"
        exit 1
    fi

    if ! grep -q "^## Competencias$" "$prompt"; then
        echo "Missing '## Competencias' heading in: $prompt"
        exit 1
    fi

    if grep -q "需求\|注意" "$prompt"; then
        echo "Found unexpected non-PT token in: $prompt"
        exit 1
    fi
done

echo "[text-lint] Checking docs references"
if ! grep -q "PADRAO-LINGUAGEM.md" "$ROOT_DIR/README.md"; then
    echo "README.md must reference PADRAO-LINGUAGEM.md"
    exit 1
fi

if ! grep -q "PADRAO-LINGUAGEM.md" "$ROOT_DIR/CONTRIBUTING.md"; then
    echo "CONTRIBUTING.md must reference PADRAO-LINGUAGEM.md"
    exit 1
fi

echo "[text-lint] OK"
