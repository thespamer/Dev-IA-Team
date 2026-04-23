# Plano de Melhorias do Dev-IA-Team

## Objetivo

Evoluir o framework em 3 fases para aumentar confiabilidade, previsibilidade e adoção sem perder a simplicidade (bash + IA chat).

## Métricas de Sucesso

- Falhas de script por parsing: 0 em cenários cobertos por teste
- Corrupção de `memory.md` em execução paralela: 0
- Cobertura mínima de testes de scripts: 80% dos fluxos críticos
- Tempo de onboarding de novo usuário: < 15 min

## Fase 1 - Quick Wins (1 dia)

### Escopo

1. Padronizar linguagem e encoding dos prompts
   - Remover caracteres corrompidos e inconsistências PT/EN nos arquivos `agents/pods/*/PROMPT.md`.
   - Revisar termos para manter instruções claras e sem ambiguidades.

2. Adicionar guia operacional de melhoria
   - Criar checklist executável para manutenção do framework.
   - Definir convenções para nome de artefatos compartilhados.

3. Criar baseline de validação manual
   - Rodar fluxo mínimo: `po -> backend -> frontend -> qa/sec -> devops` em dry-run.
   - Registrar comportamento esperado por script.

### Entregáveis

- Prompts revisados e consistentes
- Checklist operacional inicial
- Documento de baseline de validação

### Critérios de aceite

- Nenhum prompt com caracteres inválidos
- Fluxo dry-run executado sem erros
- Documentação clara para operador novo

## Fase 2 - Hardening (1 semana)

### Escopo

1. Robustez de escrita em memória (concorrência)
   - Implementar lock de escrita em `activate.sh` e `update_memory.sh`.
   - Garantir integridade quando múltiplos terminais salvam ao mesmo tempo.

2. Parser robusto para `run_chain.sh`
   - Melhorar parsing de aspas e separadores `|`.
   - Tratar casos de erro com mensagens acionáveis.

3. CI de qualidade para scripts
   - Pipeline com `shellcheck` e testes automatizados de fluxo.
   - Bloqueio de merge em falhas críticas.

4. Contrato mínimo para MEMORY UPDATE
   - Definir campos obrigatórios por pod (template curto e validável).
   - Adicionar validação simples antes de salvar no `memory.md`.

### Entregáveis

- Scripts com lock de escrita
- `run_chain.sh` com parsing resiliente
- Workflow de CI para shell scripts
- Especificação de contrato para `MEMORY UPDATE`

### Critérios de aceite

- Teste de escrita paralela sem corrupção
- Arquivos `.chain` com aspas válidas executam corretamente
- CI falha quando lint/teste falhar
- Resumos fora do contrato geram aviso claro

## Fase 3 - Escala (1 mês)

### Escopo

1. Sistema de plugins para pods
   - Permitir novos pods sem alterar scripts centrais.
   - Registrar metadados do pod (nome, path, artefatos esperados).

2. Validação de artefatos compartilhados
   - Definir schema leve para `api_spec.md`, `user_stories.md` e afins.
   - Validar consistência antes de exibir em ativações seguintes.

3. Observabilidade local opcional
   - Métricas de execução por etapa (tempo, sucesso, retries).
   - Relatório simples para gargalos operacionais.

4. Governança open source
   - Adicionar `LICENSE`, `CONTRIBUTING.md` e guia de release.

### Entregáveis

- Arquitetura de plugins para pods
- Validação de artefatos compartilhados
- Relatório local de uso/execução
- Pacote de governança OSS completo

### Critérios de aceite

- Novo pod reconhecido sem editar core scripts
- Artefatos inválidos sinalizados antes de propagação
- Relatórios gerados sem impacto no fluxo principal
- Contribuidor externo consegue abrir PR seguindo guia

## Ordem Recomendada de Execução

1. Fase 1 completa
2. Fase 2 (lock + parser + CI)
3. Fase 3 (plugins + validação + governança)

## Riscos e Mitigações

- Risco: aumento de complexidade do framework
  - Mitigação: manter defaults simples e recursos avançados como opcionais.

- Risco: mudanças quebrarem fluxos existentes
  - Mitigação: testes de regressão para `activate.sh`, `run_chain.sh`, `update_memory.sh`.

- Risco: sobrecarga de documentação
  - Mitigação: documentação curta, orientada a tarefa, com exemplos executáveis.

## Próximo Passo Imediato

Iniciar pela Fase 1 com foco em padronização de prompts e baseline de validação, para reduzir ruído antes do hardening dos scripts.

## Status de Execução Inicial

- Concluído: criação do `agents/doctor.sh` para validação de setup.
- Concluído: lock de escrita em `agents/activate.sh` e `agents/update_memory.sh`.
- Concluído: lock de escrita em `agents/archive_memory.sh`.
- Concluído: parser reforçado no `agents/run_chain.sh` com validação de sintaxe e erro por linha.
- Concluído: validação opcional de contrato `## MEMORY UPDATE` em `agents/update_memory.sh` (`--validate` e `--strict-validate`).
- Concluído: CI para shell scripts em `.github/workflows/shell-ci.yml`.
- Concluído: smoke tests e regressão de parser em `agents/tests/run_smoke_tests.sh` + `agents/tests/fixtures/`.
- Concluído: testes de erro adicionais para validacao estrita e concorrencia de lock em `agents/tests/run_smoke_tests.sh`.
- Concluído: teste de timeout de lock usando configuracao por ambiente (`LOCK_MAX_ATTEMPTS`, `LOCK_SLEEP_SECONDS`).
- Concluído: limpeza de inconsistências textuais em prompts (`agents/pods/po/PROMPT.md` e `agents/pods/devops/PROMPT.md`).
- Concluído: padrao de idioma documentado em `PADRAO-LINGUAGEM.md` e aplicado aos titulos principais dos prompts.
- Concluído: lint textual de consistencia em `agents/tests/lint_text_consistency.sh`.
- Concluído: documentação atualizada em `README.md` e `PASSO-A-PASSO.md`.
