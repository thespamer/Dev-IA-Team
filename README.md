# Dev-IA-Team

A framework that simulates a complete software engineering team using AI agents — each with a defined role, persistent memory, and structured output — orchestrated by a central Supervisor.

---

## What this framework does — and what it doesn't

> **Read this before anything else.**

This framework is a **context orchestrator**, not a code executor.

When you activate a pod and paste the output into an AI, the AI **can and will generate real code** — Node.js, React components, SQL schemas, Dockerfiles, CI/CD pipelines. That output is real and usable.

What the framework does **not** do automatically:

- Write files to your disk
- Run commands (`npm install`, tests, migrations)
- Deploy anything
- Close the loop between AI output and your codebase

**You are the bridge.** You copy the AI's response, create the files, run the code, validate the result.

The value is in **coherence**: because every pod shares the same project context, memory, and inter-pod artifacts, the code each specialist generates fits together. The backend knows what the PO defined. The frontend knows what endpoints the backend designed. Security reviews what was actually built.

**This is the pre-build and build phase of development** — specification, design, code generation, review — structured, coordinated, and persistent across sessions. The execution (running, testing, deploying) is yours.

---

## Structure

```
agents/
├── SUPERVISOR.md              # Orchestrator — activated via ./activate.sh supervisor
├── activate.sh                # Main script: loads role + memory + task → prints to stdout (read-only)
├── status.sh                  # Shows task history across all pods
├── update_memory.sh           # Saves AI output back into pod memory
├── archive_memory.sh          # Moves old memory entries to memory/archive/
├── migrate_memory.sh          # One-shot: splits legacy memory.md into memory.md + memory/
├── lib/
│   └── memory.sh              # Shared helpers for the sharded memory layout
├── run_chain.sh               # Step-by-step chain runner with ENTER prompts
├── doctor.sh                  # Validates setup and required project files
├── tests/
│   ├── run_smoke_tests.sh     # Smoke tests for scripts and chain parsing
│   └── fixtures/              # Test chain files (valid/invalid parser cases)
│
├── chains/                    # Ready-to-use chain files
│   ├── auth.chain             # Authentication system (4 steps)
│   ├── ecommerce.chain        # E-commerce with Stripe (5 steps)
│   └── saas-mvp.chain         # SaaS with billing + team management (5 steps)
│
├── context/
│   └── shared/
│       └── project.md         # Shared context — read by ALL pods on every activation
│
└── pods/
    ├── po/
    │   ├── PROMPT.md          # Role definition, skills, output formats, memory instructions
    │   ├── memory.md          # Curated state — schemas, endpoints, decisions (hand-edited)
    │   ├── memory/            # Entry log — one file per entry, never appended to
    │   │   └── archive/       # Older entries, moved out of the prompt by archive_memory.sh
    │   └── context/           # Artifacts: user_stories.md, roadmap.md, decisions.md
    ├── backend/
    │   ├── PROMPT.md
    │   ├── memory.md
    │   └── context/           # api_specs.md, schemas.md, services.md
    ├── frontend/
    ├── qa/
    ├── sec/
    ├── devops/
    └── supervisor/            # Created on first supervisor activation (memory only)
```

---

## How It Works

```
1. You run: ./activate.sh <pod> "<task>"
            ↓
2. Terminal prints: SYSTEM PROMPT + SHARED CONTEXT + INTER-POD ARTIFACTS + MEMORY + TASK
            ↓
3. You copy the full output → paste into AI chat (Claude, ChatGPT, etc.)
            ↓
4. The AI executes the task in the role of that pod
            ↓
5. You run: ./update_memory.sh <pod> "<summary of AI output>"
            → writes ONE NEW FILE in pods/<pod>/memory/, never appends
            ↓
6. Next pod activation will see all previous decisions in context
```

No API keys. No server. No dependencies. Just bash + an AI chat.

**Or skip the copy-paste** — pipe straight into a headless agent:

```bash
TASK="Implement GET /api/v1/users with pagination"
./activate.sh --raw backend "$TASK" | claude -p | ./update_memory.sh --stdin --task="$TASK" backend
```

`--raw` puts only the prompt on stdout; banners and tips go to stderr.

---

## Quickstart

```bash
git clone https://github.com/thespamer/Dev-IA-Team.git
cd Dev-IA-Team/agents

# Validate local setup before first run
./doctor.sh

# Fill in your project details (read by all pods)
nano context/shared/project.md

# Activate your first pod
./activate.sh po "Define user stories for a login feature with email + social login"
```

The terminal prints everything. Copy it. Paste into your AI chat. Done.

---

## Memory layout

Each pod keeps memory in two places, on purpose:

| Path | What it is | Who writes it |
|------|-----------|---------------|
| `pods/<pod>/memory.md` | **Curated state** — schemas, endpoints, standing decisions | You, by hand, reviewed in PR |
| `pods/<pod>/memory/*.md` | **Entry log** — one file per AI output, immutable | `update_memory.sh` |
| `pods/<pod>/memory/archive/` | Entries retired from the prompt | `archive_memory.sh` |

Both are loaded on every activation. The split exists because they have different
lifecycles: the log is append-only history, the state is something a human keeps true.

### Migrating an existing checkout

Older versions kept both in a single `memory.md`. Run once:

```bash
./migrate_memory.sh --dry-run    # show what would move
./migrate_memory.sh              # split the log out into memory/0000-legacy.md
```

The curated header stays in `memory.md`; the appended task log becomes a single
legacy entry. The script is idempotent — re-running it is a no-op.

---

## The Pods

| Pod | Role | Skills |
|-----|------|--------|
| `po` | Product Owner | User stories, MoSCoW, roadmap, MVP definition |
| `backend` | Backend Developers | REST/GraphQL APIs, databases, auth, caching |
| `frontend` | Frontend Developers | React/Vue components, state management, accessibility |
| `qa` | Quality Assurance | Test plans, automation, bug triage, quality gates |
| `sec` | Security Engineers | OWASP Top 10, OAuth2/JWT, vulnerability assessment |
| `devops` | DevOps Analysts | CI/CD, Docker/K8s, Terraform, monitoring |
| `supervisor` | Supervisor | Receives a "wish" and outputs the full execution plan |

---

## Scripts

### `doctor.sh` — Validate local setup

Runs a health check for required files, executable scripts, pod prompts/memory files, shared context, and chain basics:

```bash
./doctor.sh
```

If it finds critical failures, it exits with non-zero status so you can catch issues early.

---

### `activate.sh` — Activate a pod

```bash
./activate.sh [--raw] [--memory-limit=N] <pod> "<task>"
```

**`activate.sh` never writes to pod memory.** It only reads. Memory is written by
`update_memory.sh`, after the AI has actually answered.

| Flag | Effect |
|------|--------|
| *(none)* | Prints the full assembled context to stdout |
| `--raw` | Prints **only the prompt** to stdout; banner and tips go to stderr |
| `--memory-limit=N` | Include only the N most recent memory entries (default: `20`, `0` = all) |

```bash
# Standard activation
./activate.sh backend "Implement GET /api/v1/users with pagination"

# Clean prompt for a headless agent
./activate.sh --raw backend "Implement GET /api/v1/users with pagination" | claude -p

# Full memory instead of the last 20 entries
./activate.sh --memory-limit=0 backend "Audit every endpoint we have shipped"

# Activate the supervisor to get a full execution plan
./activate.sh supervisor "I want to build a SaaS with auth, Stripe billing, and team management"
```

What the terminal shows:
```
╔══════════════════════════════════════════════════════════╗
║  Backend Developers Pod Activated
╚══════════════════════════════════════════════════════════╝

[INFO] Pod:  Backend Developers (backend)
[INFO] Task: Implement GET /api/v1/users with pagination

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

=== SYSTEM PROMPT ===
[full role definition from PROMPT.md]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

=== SHARED PROJECT CONTEXT ===
[content of context/shared/project.md — your tech stack, decisions]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

=== INTER-POD ARTIFACTS (outputs de outros pods) ===
--- api_spec ---
[content of context/shared/api_spec.md — if it exists]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

=== MEMORY (Contexto Persistente) ===
[full task history from memory.md]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

=== TASK TO EXECUTE ===
Implement GET /api/v1/users with pagination

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Pod ativado (memória não foi modificada — activate.sh é read-only)
[TIP]  Após receber a resposta da IA, salve o output:
       ./update_memory.sh backend "<resumo das decisões>"
```

---

### `update_memory.sh` — Save AI output to memory

After the AI responds, save the key decisions so the next pod sees them:

```bash
./update_memory.sh <pod> "<summary>"
./update_memory.sh --task="<task>" <pod> "<summary>"
./update_memory.sh --stdin <pod> < ai-response.md
./update_memory.sh --validate <pod> "<summary with MEMORY UPDATE block>"
./update_memory.sh --strict-validate <pod> "<summary with MEMORY UPDATE block>"
```

```bash
./update_memory.sh backend "API de auth implementada: POST /auth/login retorna JWT RS256 1h,
POST /auth/register com bcrypt 12 rounds. Schema users (id, email, password_hash, name).
AuthService com register/login/logout/resetPassword."

./update_memory.sh po "US-001 a US-005 criadas. MVP = auth + dashboard (Must Have).
Phase 2 = billing + social login (Should Have). Total: 18 story points no MVP."
```

Each call writes **one new file** under `pods/<pod>/memory/`, stamped with author,
branch and UTC timestamp — it never appends to a shared file. That is what makes the
framework safe for several developers at once: two people writing to the same pod
produce two different files, so there is no merge conflict to resolve.

| Flag | Effect |
|------|--------|
| `--task="<task>"` | Records the originating task in the entry's frontmatter and filename |
| `--stdin` | Reads the summary from stdin, for piping a headless agent's output |

Author identity comes from `DEVIA_AUTHOR`, falling back to `git config user.email`.

Locks here only serialize processes on the **same machine** — across machines, git is
what serializes. Retry behavior:
- `LOCK_MAX_ATTEMPTS` (default: `100`)
- `LOCK_SLEEP_SECONDS` (default: `0.1`)

Validation flags:
- `--validate`: warns if the summary does not include `## MEMORY UPDATE` + at least 3 bullet lines.
- `--strict-validate`: fails when the summary format does not match that minimum contract.

Example with strict validation:

```bash
./update_memory.sh --strict-validate backend "## MEMORY UPDATE
- [Endpoints definidos/implementados: METHOD /path — descricao]
- [Schemas criados: tabela — campos principais]
- [Decisoes arquiteturais: choice feita + motivo]"
```

---

### `status.sh` — View task history

```bash
./status.sh           # Summary of all pods
./status.sh backend   # Full history of a specific pod
```

Output example:
```
╔══════════════════════════════════════════════════════════╗
║  Dev-IA-Team — Status Geral                              ║
╚══════════════════════════════════════════════════════════╝

● [po]       Product Owner
    Tasks: 3  |  Última: 2026-03-18 14:30:00
    └─ Define user stories for auth: register, login, logout, password...

● [backend]  Backend Developers
    Tasks: 2  |  Última: 2026-03-18 15:10:00
    └─ Implement auth API: POST /auth/register, POST /auth/login...

○ [frontend] Frontend Developers  (sem tarefas)
○ [qa]       Quality Assurance    (sem tarefas)

Total de tarefas executadas: 5

=== Artefatos Compartilhados (2) ===
  project.md     (45 linhas)
  api_spec.md    (120 linhas)
```

---

### `run_chain.sh` — Step-by-step chain runner

Guides you through a multi-step chain, one step at a time, pausing for confirmation:

```bash
./run_chain.sh chains/auth.chain
./run_chain.sh chains/ecommerce.chain
./run_chain.sh chains/saas-mvp.chain
./run_chain.sh my-project.chain        # your own chain
```

Parser notes:
- Tasks must be wrapped in double quotes.
- `parallel` lines are split only on `|` outside quotes.
- Literal `|` inside quoted task text is supported.
- Invalid chain syntax now fails fast with line-specific errors.

What it looks like:
```
╔══════════════════════════════════════════════════════════╗
║  Chain Runner — Authentication System
╚══════════════════════════════════════════════════════════╝

  Chain file:  chains/auth.chain
  Total steps: 4 (2 parallel)

Pressione ENTER para começar...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 1 of 4

Execute no terminal:

  ./activate.sh po "Define user stories para auth..."

Depois:
  1. Copie o output completo
  2. Cole no seu chat de IA
  3. Salve o resultado: ./update_memory.sh po "<resumo>"

Pressione ENTER quando estiver pronto para o próximo step...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2 of 4  (PARALELO — abra terminais separados)

Terminal 1:
  ./activate.sh backend "Implemente API de auth..."

Terminal 2:
  ./activate.sh frontend "Construa UI de auth..."

Pressione ENTER quando TODOS os terminais paralelos estiverem concluídos...
```

---

### `archive_memory.sh` — Keep memory lean

When a pod accumulates more entries than the prompt should carry, move the old ones out:

```bash
./archive_memory.sh                     # All pods, keep the 20 most recent entries each
./archive_memory.sh backend             # Only backend
./archive_memory.sh backend --keep=10   # Keep only the 10 most recent in backend
```

Entries move from `memory/` to `memory/archive/`. They stay in git — they just stop
being loaded into the prompt. The curated `memory.md` is never touched.

---

## Inter-Pod Communication via Shared Context

Pods share information through `context/shared/`:

```
context/shared/
├── project.md     ← Fill this in once — read by ALL pods on every activation
├── api_spec.md    ← Backend writes here after defining the API
├── user_stories.md ← PO writes here for other pods to read
└── [any .md file] ← Any file here is loaded by activate.sh as "INTER-POD ARTIFACTS"
```

**Example flow:**

```bash
# Step 1: Backend defines and saves the API spec
./activate.sh backend "Design auth API. Save spec to context/shared/api_spec.md"
# AI responds with full API spec, instructs you to save it
cp pods/backend/context/api_specs.md context/shared/api_spec.md

# Step 2: Frontend automatically receives the API spec
./activate.sh frontend "Build auth UI components"
# activate.sh loads context/shared/api_spec.md under "=== INTER-POD ARTIFACTS ==="
# The frontend AI now knows all endpoints, request/response formats, auth headers
```

---

## Memory System

Every pod has a `memory.md` that grows over time:

```
# Backend - Memória Persistente

## Projeto Atual
Node.js + Express, PostgreSQL 15, JWT RS256

## Endpoints
| Method | Path | Descrição | Status |
...

## Tarefa Executada em 2026-03-18 10:30:00
**Task**: Design auth API: register, login, logout endpoints

### Output salvo em 2026-03-18 10:45:00
Implementada API de auth: POST /auth/login retorna JWT RS256 1h.
Schema users criado com bcrypt 12 rounds. AuthService com 4 métodos.

## Tarefa Executada em 2026-03-18 14:00:00
**Task**: Add rate limiting to auth endpoints

### Output salvo em 2026-03-18 14:20:00
Rate limiting: 5 tentativas/min no /login, 3/min no /register. Redis para counters.
```

The task input is saved automatically by `activate.sh`. The AI output summary is saved by you via `update_memory.sh`. Together they create a full audit trail.

---

## Example: Full Chain in Practice

**Your wish:** "Build a user authentication system with registration, login, logout, and password recovery."

**Step 1 — Terminal:** run the chain runner
```bash
cd agents
./run_chain.sh chains/auth.chain
```

Or run manually, step by step:

```bash
# Step 1 — PO defines the work
./activate.sh po "Define user stories for authentication: register (email + password),
login, logout, password recovery. MoSCoW: register + login + recovery = Must Have.
Social login = Should Have (Phase 2). Define acceptance criteria for each story."
# → Paste output into AI → get user stories US-001 to US-006
./update_memory.sh po "US-001 register, US-002 login, US-003 logout, US-004 recovery criadas.
MVP = US-001 a US-004 (Must Have). Social login Phase 2. Total 12 story points."

# Step 2a — Backend (open Terminal 1)
./activate.sh backend "Implement auth API based on user stories US-001 to US-004:
POST /api/v1/auth/register (email, password, name → JWT),
POST /api/v1/auth/login (email, password → JWT + refresh token),
POST /api/v1/auth/logout (invalidate refresh token),
POST /api/v1/auth/forgot-password (send recovery email),
POST /api/v1/auth/reset-password (token + new password).
Use bcrypt rounds=12. Define schemas: users, sessions.
Save API spec to context/shared/api_spec.md"
# → Paste output into AI → get API spec, schemas, AuthService
./update_memory.sh backend "5 endpoints auth implementados. JWT RS256 1h, refresh 7d com rotação.
Schema users (id, email, password_hash, name, created_at), sessions (id, user_id, expires_at).
AuthService: register, login, logout, resetPassword."
cp pods/backend/context/api_specs.md context/shared/api_spec.md

# Step 2b — Frontend (open Terminal 2, run in parallel with 2a)
./activate.sh frontend "Build auth UI: LoginForm (email, password, loading/error states),
RegisterForm (name, email, password, confirm, validation), ForgotPasswordForm,
ResetPasswordForm. React + Tailwind. WCAG 2.1 AA. All forms need loading, error, success states."
# → Paste output into AI → get component specs
./update_memory.sh frontend "4 componentes de auth criados: LoginForm, RegisterForm,
ForgotPasswordForm, ResetPasswordForm. Design tokens definidos. ARIA labels em todos os inputs."

# Step 3a — QA (Terminal 1)
./activate.sh qa "Test plan for auth system: unit (hash, token gen, email validation),
integration (all 5 endpoints: valid + invalid inputs), E2E (full register→login→logout flow,
password recovery flow). Edge cases: duplicate email, expired token, wrong password 3x.
Quality gate: 80% coverage, 0 open critical bugs."
./update_memory.sh qa "Test plan criado: 28 casos de teste. Unit 15, integration 8, E2E 5.
Quality gate: 80% cobertura, 0 bugs críticos. Automação: Jest + Playwright."

# Step 3b — Security (Terminal 2, run in parallel with 3a)
./activate.sh sec "OWASP review of auth system: A07 brute force (rate limiting on /login),
JWT implementation (RS256, no 'none', 1h expiry, refresh rotation),
bcrypt rounds >= 12, reset token (entropy, 15min expiry, single-use),
user enumeration on /forgot-password (same response for existing/non-existing email)."
./update_memory.sh sec "Security review auth: 3 findings. HIGH: no rate limiting (fix before deploy).
MEDIUM: reset token expiry 1h (should be 15min). LOW: password complexity not enforced.
JWT RS256 OK. bcrypt 12 rounds OK."

# Step 4 — DevOps
./activate.sh devops "CI/CD for auth service: Dockerfile (multi-stage, node:alpine, non-root user,
< 100MB), GitHub Actions (lint → unit tests → integration tests → trivy scan → build → staging →
manual gate → prod). Quality gates: 80% coverage, 0 critical CVEs.
Alert: > 10 failed logins/minute (brute force detection)."
./update_memory.sh devops "Dockerfile multi-stage criado: 82MB final. Pipeline GitHub Actions 6 stages.
Quality gates configurados. Alert brute-force no Prometheus/AlertManager."
```

---

## Creating a Custom Chain File

```bash
# Create your chain file
cat > chains/my-feature.chain << 'EOF'
name=My Feature

# PO always first
step po "Define user stories for [your feature]..."

# Parallel when independent
parallel backend "Build the API for [feature]..." | frontend "Build the UI for [feature]..."

# Parallel reviews
parallel qa "Test plan for [feature]..." | sec "Security review for [feature]..."

# DevOps last
step devops "CI/CD and infrastructure for [feature]..."
EOF

# Run it
./run_chain.sh chains/my-feature.chain
```

---

## Requirements

- **Bash** (for all scripts)
- **An AI assistant** (Claude, ChatGPT, or any LLM) to execute the loaded context

```bash
git clone https://github.com/thespamer/Dev-IA-Team.git
cd Dev-IA-Team/agents
nano context/shared/project.md   # fill in your project
./activate.sh supervisor "I want to build [your project description]"
```

---

## Contributing

See `CONTRIBUTING.md` for contribution workflow, script quality checks, and pull request expectations.
Language consistency rules are documented in `PADRAO-LINGUAGEM.md`.

---

## CI and Tests

- GitHub Actions workflow: `.github/workflows/shell-ci.yml`
- Checks included:
  - `shellcheck` linting for all core shell scripts
  - smoke tests via `agents/tests/run_smoke_tests.sh`
  - text consistency lint via `agents/tests/lint_text_consistency.sh`
  - strict `MEMORY UPDATE` validation behavior
  - lock contention behavior for memory writes
  - lock-timeout failure behavior
- Local run:

```bash
./agents/tests/run_smoke_tests.sh
```

---

## License

MIT
