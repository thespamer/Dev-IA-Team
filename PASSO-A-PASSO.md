# Passo a Passo: Rodando o Dev-IA-Team do Zero

> **Cenário deste guia:** vamos construir o MVP de um app chamado **TaskFlow** — uma plataforma de gestão de tarefas com board kanban.
> Você vai passar por todos os 6 papéis do time, na ordem certa, e ver como cada agente conversa com o próximo.

---

## O que você precisa

- Um terminal (Linux ou Mac)
- Uma conta em qualquer IA: [Claude](https://claude.ai), [ChatGPT](https://chat.openai.com), ou qualquer outra
- O repositório clonado (se ainda não fez):

```bash
git clone https://github.com/thespamer/Dev-IA-Team.git
cd Dev-IA-Team/agents
```

---

## Como o fluxo funciona (leia antes de começar)

```
1. Você roda um comando no terminal
         ↓
2. O terminal imprime um bloco grande de texto
         ↓
3. Você seleciona TUDO (Ctrl+A), copia (Ctrl+C)
         ↓
4. Abre o Claude/ChatGPT, cola (Ctrl+V) e envia
         ↓
5. A IA responde no papel do especialista
         ↓
6. Você roda outro comando para salvar o resumo na memória
         ↓
7. O próximo agente já sabe o que foi decidido
```

Sem mágica. Sem API. Você é o "fio" que conecta tudo.

---

## ETAPA 0 — Confirme que o projeto está configurado

O arquivo `context/shared/project.md` já vem preenchido com o TaskFlow. Dê uma olhada:

```bash
cat context/shared/project.md
```

Você vai ver o nome do projeto, a stack (Node.js, React, PostgreSQL) e os ambientes definidos. Todos os agentes vão ler esse arquivo automaticamente.

---

## ETAPA 1 — Product Owner (PO)

**O que ele faz:** transforma a ideia em histórias de usuário com critérios de aceite e prioridades.

### 1.1 — Rode no terminal

```bash
./activate.sh po "Defina as histórias de usuário para o MVP do TaskFlow: cadastro e login de usuário, criação e listagem de tarefas, board kanban com 3 colunas (To Do, In Progress, Done), e notificação por email quando uma tarefa é atribuída. Use MoSCoW para priorizar. Defina critérios de aceite para cada história."
```

### 1.2 — Copie o output

O terminal vai imprimir algo assim:

```
╔══════════════════════════════════════════════════════════╗
║  Product Owner Pod Activated
╚══════════════════════════════════════════════════════════╝

=== SYSTEM PROMPT ===
# POD: Product Owner (PO)
...

=== SHARED PROJECT CONTEXT ===
# Projeto — TaskFlow
...

=== MEMORY (Contexto Persistente) ===
...

=== TASK TO EXECUTE ===
Defina as histórias de usuário para o MVP do TaskFlow...
```

**Selecione tudo com `Ctrl+A` → copie com `Ctrl+C`.**

### 1.3 — Cole na IA

Abra o Claude ou ChatGPT. Cole o conteúdo copiado e envie. A IA vai responder como um Product Owner, gerando algo parecido com:

```
## US-001: Cadastro de usuário
**Como** visitante
**Preciso** me cadastrar com nome, email e senha
**Para** ter acesso à plataforma

### Critérios de Aceite
- [ ] Email deve ser único no sistema
- [ ] Senha mínima de 8 caracteres
- [ ] Confirmação por email após cadastro

### Estimativa: 3 story points | Prioridade: Must Have
...
```

### 1.4 — Salve o resumo na memória

Após receber a resposta, rode (adapte o resumo ao que a IA gerou):

```bash
./update_memory.sh po "US-001 cadastro (Must Have, 3pts), US-002 login (Must Have, 2pts), US-003 criar tarefa (Must Have, 3pts), US-004 listar tarefas (Must Have, 2pts), US-005 kanban board (Must Have, 5pts), US-006 notificação email (Should Have, 3pts). MVP = US-001 a US-005. Total 15 pts."
```

---

## ETAPA 2 — Backend

**O que ele faz:** projeta a API, os endpoints e o banco de dados. O resultado vai para um arquivo compartilhado que o Frontend vai ler automaticamente.

### 2.1 — Rode no terminal

```bash
./activate.sh backend "Com base nas histórias US-001 a US-005 do TaskFlow, implemente a API REST: POST /api/v1/auth/register, POST /api/v1/auth/login, POST /api/v1/auth/logout, GET /api/v1/tasks, POST /api/v1/tasks, PATCH /api/v1/tasks/:id (atualizar status entre To Do / In Progress / Done), DELETE /api/v1/tasks/:id. Defina schemas: users e tasks. Use JWT RS256. Ao finalizar, apresente o spec da API em formato Markdown para ser salvo em context/shared/api_spec.md"
```

> **Observe:** o terminal agora vai incluir a seção `=== MEMORY ===` com o histórico do PO, porque você salvou no passo anterior. O Backend já sabe o que foi decidido.

### 2.2 — Copie, cole na IA, receba a resposta

A IA vai gerar os endpoints, schemas, e o spec da API.

### 2.3 — Salve o spec no contexto compartilhado

A IA vai incluir um bloco `## MEMORY UPDATE` no final da resposta. Pegue o spec da API que ela gerou e salve:

```bash
# Crie o arquivo com o conteúdo que a IA gerou
nano context/shared/api_spec.md
# Cole o spec → Ctrl+O para salvar → Ctrl+X para sair
```

### 2.4 — Salve na memória do Backend

```bash
./update_memory.sh backend "7 endpoints implementados: auth (register/login/logout) + tasks (CRUD + status). Schema users: id, email, password_hash, name, created_at. Schema tasks: id, title, description, status, assigned_to, created_by, created_at. JWT RS256 1h. Spec salvo em context/shared/api_spec.md"
```

---

## ETAPA 3 — Frontend

**O que ele faz:** projeta os componentes de tela. Ele já vai receber o spec da API automaticamente — sem você precisar explicar nada.

### 3.1 — Rode no terminal

```bash
./activate.sh frontend "Com base no projeto TaskFlow, crie os componentes React para o MVP: LoginForm, RegisterForm, TaskBoard (kanban com 3 colunas), TaskCard, CreateTaskModal. Use Tailwind CSS. Garanta acessibilidade WCAG 2.1 AA (aria-labels, navegação por teclado). Todos os componentes devem ter estados de loading, erro e sucesso."
```

> **Observe:** o terminal vai incluir uma seção `=== INTER-POD ARTIFACTS ===` com o `api_spec.md` que o Backend criou. O Frontend já sabe os endpoints sem você explicar.

### 3.2 — Copie, cole na IA, receba os componentes

### 3.3 — Salve na memória

```bash
./update_memory.sh frontend "5 componentes criados: LoginForm, RegisterForm, TaskBoard (kanban 3 colunas), TaskCard, CreateTaskModal. Tailwind CSS. WCAG 2.1 AA com aria-labels. Estados loading/error/success em todos. Integração com /api/v1/auth e /api/v1/tasks."
```

---

## ETAPA 4 — QA e Security (em paralelo)

**Agora ficou interessante:** QA e Security podem trabalhar ao mesmo tempo, em dois terminais separados — exatamente como num time real.

### Abra dois terminais

**Terminal 1 — QA:**

```bash
./activate.sh qa "Crie o plano de testes para o MVP do TaskFlow cobrindo: testes unitários (validação de campos, geração de token JWT, regras de negócio do kanban), testes de integração (todos os 7 endpoints: fluxos válidos e inválidos), testes E2E (fluxo completo: register → login → criar tarefa → mover no kanban → logout). Defina quality gates: cobertura mínima, critérios para deploy."
```

**Terminal 2 — Security:**

```bash
./activate.sh sec "Faça o review de segurança OWASP Top 10 do TaskFlow focando em: A01 (controle de acesso nas tarefas — usuário só vê suas próprias), A07 (brute force no login — rate limiting), implementação JWT (RS256, expiração, rotação de refresh), validação de inputs (SQL injection, XSS nos campos de tarefa), enumeração de usuário no /register."
```

### Cole cada output no Claude/ChatGPT separadamente e salve:

```bash
./update_memory.sh qa "Plano de testes: 24 casos. Unit: 10 (auth + tasks). Integration: 9 (7 endpoints + edge cases). E2E: 5 (fluxos principais). Quality gate: 80% cobertura, 0 bugs críticos abertos. Stack: Jest + Playwright."

./update_memory.sh sec "Review OWASP: 4 findings. CRITICAL: sem rate limiting no /login (implementar antes do deploy). HIGH: sem validação de ownership nas tasks (qualquer user pode editar task de outro). MEDIUM: refresh token sem rotação. LOW: sem política de senha complexa. JWT RS256 OK."
```

---

## ETAPA 5 — DevOps

**O que ele faz:** empacota tudo e define como o sistema chega em produção.

### 5.1 — Rode no terminal

```bash
./activate.sh devops "Configure a infraestrutura do TaskFlow: Dockerfile multi-stage para a API Node.js (imagem final < 100MB, usuário não-root), pipeline GitHub Actions com stages: lint → unit tests → integration tests → trivy scan (0 CVEs críticos) → build → deploy staging → aprovação manual → deploy prod. Defina alertas: > 10 logins com falha por minuto (brute force), latência p95 > 500ms, taxa de erro > 1%."
```

### 5.2 — Cole na IA, receba a infraestrutura

### 5.3 — Salve na memória

```bash
./update_memory.sh devops "Dockerfile multi-stage: 87MB, non-root user. Pipeline 7 stages com quality gates. Trivy scan bloqueante para CVEs críticos. Alertas configurados: brute-force (10 falhas/min), latência p95 > 500ms, error rate > 1%. Deploy prod com aprovação manual."
```

---

## ETAPA 6 — Veja o status geral do time

```bash
./status.sh
```

Você vai ver algo assim:

```
╔══════════════════════════════════════════════════════════╗
║  Dev-IA-Team — Status Geral                              ║
╚══════════════════════════════════════════════════════════╝

● [po]       Product Owner         Tasks: 1  |  Última: 2026-03-20 10:15:00
● [backend]  Backend Developers    Tasks: 1  |  Última: 2026-03-20 10:32:00
● [frontend] Frontend Developers   Tasks: 1  |  Última: 2026-03-20 10:48:00
● [qa]       Quality Assurance     Tasks: 1  |  Última: 2026-03-20 11:02:00
● [sec]      Security Engineers    Tasks: 1  |  Última: 2026-03-20 11:04:00
● [devops]   DevOps Analysts       Tasks: 1  |  Última: 2026-03-20 11:20:00

Total de tarefas executadas: 6

=== Artefatos Compartilhados (2) ===
  project.md     (32 linhas)
  api_spec.md    (48 linhas)
```

---

## Dica: use o `--dry-run` para visualizar sem registrar

Se quiser ver o que um agente receberia sem salvar nada na memória:

```bash
./activate.sh --dry-run sec "Review de segurança no módulo de tarefas"
```

Útil para explorar, testar ou entender o contexto antes de executar.

---

## Recapitulando o fluxo completo

```
ETAPA 1 → PO           define o escopo e as histórias
ETAPA 2 → Backend      projeta a API e salva o spec compartilhado
ETAPA 3 → Frontend     recebe o spec automaticamente e projeta os componentes
ETAPA 4 → QA + Sec     revisão de qualidade e segurança em paralelo
ETAPA 5 → DevOps       empacota e entrega
ETAPA 6 → status.sh    visão geral do time
```

Em cada etapa:
1. `./activate.sh <pod> "<tarefa>"` → imprime o contexto completo
2. Copia → cola na IA → recebe a resposta
3. `./update_memory.sh <pod> "<resumo>"` → salva para o próximo agente ler

---

## Usando a cadeia pronta (atalho)

Se preferir ser guiado passo a passo automaticamente, use o runner de cadeia:

```bash
./run_chain.sh chains/auth.chain
```

Ele vai te dizer exatamente quando rodar cada agente, quando esperar o paralelo e quando avançar — com `ENTER` entre cada etapa.

---

## Próximos passos

- Edite `context/shared/project.md` com o **seu** projeto real
- Rode `./activate.sh supervisor "Quero construir [sua ideia]"` para receber um plano completo gerado pelo Supervisor
- Crie sua própria cadeia em `chains/meu-projeto.chain` seguindo os exemplos existentes
