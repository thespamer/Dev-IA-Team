# Contributing to Dev-IA-Team

Obrigado por contribuir com o Dev-IA-Team.

## Fluxo Recomendado

1. Crie uma branch para sua mudanca.
2. Rode validacoes locais antes de abrir PR.
3. Atualize a documentacao quando alterar comportamento de scripts.
4. Abra PR com descricao objetiva do problema e da solucao.

## Validacoes Locais

No root do repositorio:

```bash
./agents/doctor.sh
bash -n agents/activate.sh
bash -n agents/update_memory.sh
bash -n agents/run_chain.sh
bash -n agents/archive_memory.sh
./agents/tests/run_smoke_tests.sh
./agents/tests/lint_text_consistency.sh
```

Para testar timeout de lock localmente, use:

```bash
LOCK_MAX_ATTEMPTS=3 LOCK_SLEEP_SECONDS=0.01 ./agents/update_memory.sh --strict-validate po "## MEMORY UPDATE
- item 1
- item 2
- item 3"
```

Se voce alterou outros scripts shell, inclua `bash -n` neles tambem.

## Convencoes

- Mantenha scripts portaveis em bash.
- Preserve o fluxo principal: `activate -> IA chat -> update_memory`.
- Evite quebrar compatibilidade de chain files existentes.
- Sempre documente novas flags/comportamentos em `README.md` e/ou `PASSO-A-PASSO.md`.
- Siga o padrao de idioma por arquivo em `PADRAO-LINGUAGEM.md`.

## Pull Request Checklist

- [ ] Mudanca implementada e validada localmente
- [ ] Documentacao atualizada
- [ ] Sem regressao no fluxo de chain files existentes
- [ ] Mensagens de erro claras para usuario final
