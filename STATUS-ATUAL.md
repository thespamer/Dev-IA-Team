# Status Atual - Melhorias do Framework

Ultima atualizacao: 2026-09-24

## Concluido

- Plano macro criado em `PLANO-MELHORIAS.md`.
- Cadeia de melhorias criada em `agents/chains/framework-improvements.chain`.
- Lock de escrita implementado em:
  - `agents/activate.sh`
  - `agents/update_memory.sh`
  - `agents/archive_memory.sh`
- Health check criado em `agents/doctor.sh`.
- Validacao opcional de contrato para memoria em `agents/update_memory.sh`:
  - `--validate`
  - `--strict-validate`
- Parser do chain runner reforcado em `agents/run_chain.sh`:
  - split de `parallel` respeitando aspas
  - validacao de sintaxe com erro por linha
- Testes de regressao de parser adicionados em `agents/tests/fixtures/`.
- Smoke tests adicionados em `agents/tests/run_smoke_tests.sh`.
- Testes de erro adicionados no smoke:
  - falha esperada em `--strict-validate`
  - contencao de lock em escrita de memoria
  - timeout de lock com `LOCK_MAX_ATTEMPTS` e `LOCK_SLEEP_SECONDS`
- CI de shell scripts criado em `.github/workflows/shell-ci.yml`.
- Padrao de idioma documentado em `PADRAO-LINGUAGEM.md`.
- Lint de consistencia textual adicionado em `agents/tests/lint_text_consistency.sh`.
- Titulos principais dos prompts padronizados para Portugues em:
  - `agents/pods/backend/PROMPT.md`
  - `agents/pods/frontend/PROMPT.md`
  - `agents/pods/qa/PROMPT.md`
  - `agents/pods/sec/PROMPT.md`
  - `agents/pods/devops/PROMPT.md`
  - `agents/pods/po/PROMPT.md`
- Ajustes de prompt em:
  - `agents/pods/po/PROMPT.md`
  - `agents/pods/devops/PROMPT.md`
- Documentacao atualizada:
  - `README.md`
  - `PASSO-A-PASSO.md`
  - `CONTRIBUTING.md`
  - `LICENSE`

## Concluido - Memoria em Shards (uso por N devs)

- Memoria reestruturada em duas camadas:
  - `pods/<pod>/memory.md` = estado curado, editado a mao
  - `pods/<pod>/memory/*.md` = log de entradas, um arquivo por entrada
  - `pods/<pod>/memory/archive/` = entradas retiradas do prompt
- Helpers compartilhados criados em `agents/lib/memory.sh`.
- `update_memory.sh` passou a escrever arquivo novo por entrada (nunca append).
  Elimina a classe de conflito de merge quando dois devs tocam o mesmo pod.
- Frontmatter com autoria (`author`, `branch`, `date`, `task`) em cada entrada.
  Origem do autor: `DEVIA_AUTHOR` ou `git config user.email`.
- `activate.sh` virou read-only sobre a memoria. Log de execucao movido para
  `.runlog/<autor>.log` (um arquivo por autor, sem conflito).
- `activate.sh --raw` emite so o prompt em stdout (banner e dicas vao para stderr),
  habilitando pipe direto para agente headless.
- `activate.sh --memory-limit=N` limita quantas entradas entram no prompt (default 20).
- `update_memory.sh --stdin` e `--task=` para fechar o loop headless.
- `archive_memory.sh` reescrito: move arquivos para `memory/archive/` em vez de
  fazer cirurgia de linha no markdown. 183 -> 94 linhas.
- `status.sh` reescrito para ler shards e mostrar autoria.
- `migrate_memory.sh` criado: migracao idempotente do formato antigo.
- `doctor.sh` estendido: valida `memory/` por pod e detecta log legado nao migrado.
- Smoke tests reescritos para shards, incluindo:
  - `activate.sh` nao escreve em memoria
  - `--raw` sem escapes ANSI nem chrome no stdout
  - dois autores concorrentes geram dois arquivos distintos
  - shard carrega frontmatter de autoria

## Concluido - Manifesto de Artefatos por Pod

- `agents/lib/artifacts.sh` criado: selecao de artefatos inter-pod via manifesto.
- `pods/<pod>/reads.txt` criado para os 7 pods, declarando o que cada um consome.
  Nomes derivados do que cada `PROMPT.md` diz produzir.
- `activate.sh` trocou o glob de `context/shared/*.md` pela leitura do manifesto.
  Com artefatos de tamanho realista (~15 KB cada, 15 deles), a reducao de prompt
  por pod ficou entre 51% e 78%. Supervisor usa `*` de proposito.
- Entrada de manifesto apontando fora de `context/shared/` e rejeitada e
  reportada em stderr. Uma linha `../../../.ssh/id_rsa` num PR despejaria o
  arquivo no prompt enviado para a IA.
- Pod sem `reads.txt` cai no comportamento antigo (le tudo) e `activate.sh` avisa.
- `doctor.sh` ganhou a etapa [4/6]: valida manifestos e lista artefatos
  declarados que a squad ainda nao produziu.
- Smoke tests novos: selecao por manifesto, `*` do supervisor, rejeicao de
  traversal, e ativacao limpa de todo pod sem nenhum artefato presente.

## Bugs Pre-existentes Corrigidos

- `tests/lint_text_consistency.sh` falhava no `main` desde o commit 0b6c277:
  exigia `## Competencias` em `pods/supervisor/PROMPT.md`, que e orquestrador e
  nao tem essa secao. Lint passou a pular o supervisor. CI estava vermelho.
- `status.sh` usava `declare -A` (array associativo), inexistente no bash 3.2
  padrao do macOS. Trocado por `case`.

## Bugs Pre-existentes Reportados (nao corrigidos)

- `agents/pods/supervisor/PROMPT.md` e duplicata morta de `agents/SUPERVISOR.md`.
  `activate.sh` le apenas `SUPERVISOR.md`. Decidir qual manter.
- `agents/SUPERVISOR.md` tem code fences escapadas (`\`\`\``), que vazam como
  barra invertida literal no prompt montado. A duplicata em `pods/` nao tem.

## Validacao Executada

- `bash -n` em todos os scripts: OK.
- `./agents/doctor.sh`: OK (43 ok, 0 avisos, 0 falhas).
- `./agents/run_chain.sh chains/framework-improvements.chain` (ENTER automatizado): OK.
- `./agents/tests/run_smoke_tests.sh`: OK (18 casos).
- Round-trip headless verificado de ponta a ponta:
  `activate.sh --raw | <agente> | update_memory.sh --stdin` e a decisao aparece
  na proxima ativacao do pod.

## Pendencias Sugeridas para Proxima Sessao

Prioridade alta (destrava uso por squad):

1. Contrato de memoria obrigatorio: `--strict-validate` por padrao e o bloco
   `## MEMORY UPDATE` exigido no `PROMPT.md` de cada pod, para a IA emitir o
   resumo em vez de o humano redigitar. Precisa de fallback pensado para quando
   a IA nao emitir o bloco — `exit 1` puro vai irritar a squad.

Prioridade media:

2. `CODEOWNERS` por pod (precisa dos handles reais do time no GitHub).
3. `context/shared/project.md` esta commitado com dados de exemplo (TaskFlow).
   Virar `project.example.md` e fazer o `doctor.sh` pedir o real no primeiro uso.
4. Resolver a duplicata do prompt do supervisor e as code fences escapadas.
5. Revisar os `reads.txt` default: os nomes saem do que cada `PROMPT.md` declara
   produzir, mas quem consome o que e decisao de arquitetura do time.

Prioridade baixa:

6. Padronizar acentuacao/ASCII nos templates de memoria.
7. Expandir lint textual para cobertura semantica mais ampla.
8. Pods escrevem em `context/` (privado) mas `activate.sh` so le
   `context/shared/`. Hoje o `context/` privado de cada pod nao entra em prompt
   nenhum — decidir se e intencional ou se falta promover.

## Ponto de Retomada

Retomar pelo item 1 (contrato de memoria obrigatorio).
