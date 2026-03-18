# Dev-IA-Team

A framework that simulates a complete software engineering team using AI agents — each with a defined role, persistent memory, and structured output — orchestrated by a central Supervisor.

---

## How It Works

```
agents/
├── SUPERVISOR.md          # System prompt for the orchestrator agent
├── activate.sh            # Activates a pod: loads role + memory + task
└── pods/
    ├── po/                # Product Owner
    │   ├── PROMPT.md      #   Role + skills + output format
    │   └── memory.md      #   Persistent history of all past tasks
    ├── backend/
    ├── frontend/
    ├── qa/
    ├── sec/
    └── devops/
```

**The core loop:**

```
1. You run: ./activate.sh <pod> "<task>"
          ↓
2. Terminal prints: SYSTEM PROMPT + MEMORY + TASK
          ↓
3. You paste the output into an AI chat (Claude, ChatGPT, etc.)
          ↓
4. The AI executes the task in the role of that pod
          ↓
5. memory.md is automatically updated with the task for next time
```

No API keys. No server. Just bash + an AI chat session.

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

---

## Quickstart

```bash
git clone https://github.com/thespamer/Dev-IA-Team.git
cd Dev-IA-Team/agents
chmod +x activate.sh

# Activate any pod
./activate.sh po "Create user stories for a login feature"
```

Running the command prints everything to your terminal:

```
╔══════════════════════════════════════════════════════════╗
║  Product Owner Pod Activated
╚══════════════════════════════════════════════════════════╝

[INFO] Pod: Product Owner (po)
[INFO] Task: Create user stories for a login feature

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

=== SYSTEM PROMPT ===

# POD: Product Owner
## Papel
Responsável pelo roadmap, priorização e definição de valor...
[full role definition]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

=== MEMORY (Contexto Persistente) ===

[everything this pod has done before]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

=== TASK TO EXECUTE ===

Create user stories for a login feature

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Pod ativado com sucesso
[NOTE] A memória do pod foi atualizada com a tarefa
```

Copy the full output → paste into Claude (or any AI chat) → the AI responds as that pod.

---

## Examples: Full Chain in Practice

Below are three complete examples. For each one you'll see:
- The **wish** you type
- The **exact terminal commands** to run, step by step
- What each pod produces

---

### Example 1 — "I want a user login system"

**Your wish:**
> "Build a complete user authentication system: registration, login, logout, password recovery."

**Step 1 — Product Owner defines the work**

```bash
cd Dev-IA-Team/agents

./activate.sh po "Define user stories for a user authentication system: registration, login, logout, and password recovery. Use MoSCoW prioritization and define the MVP scope."
```

Paste output into AI chat. The PO pod responds with:
- `US-001`: As a visitor, I want to register with email + password *(Must Have)*
- `US-002`: As a user, I want to log in *(Must Have)*
- `US-003`: As a user, I want to recover my password by email *(Must Have)*
- `US-004`: As a user, I want to log in with Google *(Should Have)*
- MVP = US-001, US-002, US-003 | Phase 2 = US-004

---

**Step 2a — Backend builds the API** *(run in parallel with step 2b)*

```bash
./activate.sh backend "Implement the authentication API based on user stories US-001 to US-003:
- POST /api/v1/auth/register (email, password, name)
- POST /api/v1/auth/login (returns JWT + refresh token)
- POST /api/v1/auth/logout (invalidates token)
- POST /api/v1/auth/forgot-password (sends recovery email)
- POST /api/v1/auth/reset-password (validates token, sets new password)
Use bcrypt for passwords. Define the users and sessions DB schemas."
```

Paste output into AI chat. Backend pod responds with:
- OpenAPI spec for all 5 endpoints
- `users` table schema (id, email, password_hash, name, created_at)
- `sessions` table schema (id, user_id, token_hash, expires_at)
- `AuthService` with methods: `register()`, `login()`, `logout()`, `resetPassword()`

---

**Step 2b — Frontend builds the UI** *(run in parallel with step 2a)*

```bash
./activate.sh frontend "Build the authentication UI components:
- LoginForm (email, password fields, submit, error states)
- RegisterForm (name, email, password, confirm password, validation)
- ForgotPasswordForm (email field, success confirmation)
- ResetPasswordForm (new password, confirm, token from URL)
Use React + Tailwind. All components must meet WCAG 2.1 AA."
```

Paste output into AI chat. Frontend pod responds with:
- Component spec for each form (props, states, validation rules)
- `LoginPage` and `RegisterPage` layout definitions
- Loading, error, success states for each form
- ARIA labels and keyboard navigation for all inputs

---

**Step 3 — QA writes the test plan**

```bash
./activate.sh qa "Create a test plan for the authentication system (US-001 to US-003).
Cover:
- Unit tests: password hashing, token generation, email validation
- Integration tests: all 5 API endpoints with valid and invalid inputs
- E2E tests: full register → login → logout flow and password recovery flow
- Edge cases: duplicate email on register, expired reset token, wrong password 3 times
Quality gate: 80% code coverage, 0 open critical bugs before release."
```

Paste output into AI chat. QA pod responds with:
- Test plan document with scope and out-of-scope
- 25 test cases with steps, expected results, and test type
- Quality gate checklist for the pipeline

---

**Step 4 — Security reviews the implementation**

```bash
./activate.sh sec "Security review of the authentication system:
- Check OWASP A07:2021 (Authentication Failures): brute force, weak passwords
- Review JWT implementation: algorithm (no 'none'), expiration, refresh rotation
- Check bcrypt rounds (should be >= 12)
- Validate password reset flow: token entropy, expiration time, single-use
- Rate limiting on /login and /register endpoints
- Check for user enumeration on /forgot-password response"
```

Paste output into AI chat. Sec pod responds with:
- Security review with OWASP checklist
- Findings table (e.g., "no rate limiting on /login — HIGH severity")
- Mitigations for each finding
- Approval status: Pending (2 issues to fix before deploy)

---

**Step 5 — DevOps sets up the pipeline**

```bash
./activate.sh devops "Set up CI/CD for the authentication service:
- Dockerfile: multi-stage build, non-root user, minimal image
- GitHub Actions pipeline: lint → unit tests → integration tests → security scan → build image → deploy to staging
- Quality gates in the pipeline matching QA's plan (80% coverage)
- Alert: notify on > 10 failed logins/minute (possible brute force)"
```

Paste output into AI chat. DevOps pod responds with:
- `Dockerfile` spec (multi-stage, node:alpine, non-root)
- GitHub Actions YAML (5 stages, quality gates)
- Monitoring alert rule for brute-force detection

---

**Full chain summary for this wish:**

```bash
# 1 — Define work
./activate.sh po "Define user stories for registration, login, logout, password recovery. MoSCoW."

# 2 — Build in parallel (open two terminals or run sequentially)
./activate.sh backend "Implement auth API: register, login, logout, forgot-password, reset-password. JWT + bcrypt. Define users and sessions schemas."
./activate.sh frontend "Build auth forms: LoginForm, RegisterForm, ForgotPasswordForm, ResetPasswordForm. React + Tailwind. WCAG 2.1 AA."

# 3 — Validate
./activate.sh qa "Test plan for auth: unit, integration, E2E. Edge cases. Quality gate: 80% coverage."
./activate.sh sec "OWASP review: brute force, JWT, bcrypt, reset token, rate limiting, user enumeration."

# 4 — Ship
./activate.sh devops "Dockerfile + GitHub Actions CI/CD + quality gates + brute-force alert."
```

---

### Example 2 — "I want an e-commerce with Stripe"

**Your wish:**
> "Build an e-commerce: product catalog, cart, Stripe checkout, order tracking."

```bash
# 1 — Product Owner
./activate.sh po "User stories for e-commerce: browse products, search with filters, add to cart, Stripe checkout, view order history and status. Define MVP (3 phases)."

# 2a — Backend (parallel)
./activate.sh backend "E-commerce API:
- GET /products (list with search, filters, pagination)
- GET /products/:id
- POST /cart/items, DELETE /cart/items/:id, GET /cart
- POST /checkout/session (create Stripe session)
- POST /checkout/webhook (Stripe webhook handler)
- GET /orders, GET /orders/:id
Schemas: products, cart_items, orders, order_items, payments."

# 2b — Frontend (parallel)
./activate.sh frontend "E-commerce UI:
- ProductGrid + ProductCard + ProductDetail
- SearchBar with category/price filters
- CartDrawer (slide-in) + CartItem
- CheckoutPage with Stripe Elements
- OrderHistory + OrderTimeline
Mobile-first responsive. SSR on product pages for SEO."

# 3 — Security
./activate.sh sec "E-commerce security review:
- Stripe webhook: validate signature header
- Price tampering: server-side price validation (never trust frontend)
- PCI DSS awareness: ensure no card data is stored or logged
- SQL injection on search/filter params
- CSRF on checkout form
- Rate limiting on checkout endpoint"

# 4 — QA
./activate.sh qa "E-commerce test plan:
- Cart: add, remove, update quantity, empty cart, max items
- Checkout: successful Stripe payment, declined card, network error
- Order status transitions: pending → paid → shipped → delivered
- Concurrent cart updates from same user (race condition)
- Stripe test mode card scenarios (4242, 4000 decline codes)"

# 5 — DevOps
./activate.sh devops "E-commerce infra:
- Docker Compose (backend, frontend, postgres, redis for cart)
- GitHub Actions: test → build → staging → production with manual gate
- CDN for product images (S3 + CloudFront)
- Auto-scaling rule: scale out at 70% CPU
- Alert: payment failure rate > 5% in 5 minutes"
```

---

### Example 3 — "I want a real-time monitoring dashboard"

**Your wish:**
> "Build an internal dashboard to monitor our microservices: health, latency, error rates, and logs."

```bash
# 1 — Product Owner
./activate.sh po "Requirements for an internal observability dashboard. Users: SRE team + on-call engineers. Features: service health overview, latency p50/p95/p99, error rate trends, searchable logs, configurable alert rules."

# 2a — Backend (parallel)
./activate.sh backend "Dashboard API:
- GET /services (list all services with health status)
- GET /services/:id/metrics (latency, error rate, request rate from Prometheus)
- GET /logs (query Loki with filters: service, level, time range, text search)
- CRUD /alerts (user-defined alert rules)
- WebSocket /ws/metrics (push live metric updates every 5s)"

# 2b — DevOps (parallel — sets up the infra the backend reads from)
./activate.sh devops "Observability stack:
- Prometheus config for scraping all microservices
- Loki for log aggregation with service labels
- Grafana provisioning (datasources + base dashboards)
- Alertmanager for alert routing
- Define SLIs/SLOs: availability 99.9%, p95 latency < 300ms, error rate < 1%
Deliver as Terraform modules."

# 3 — Frontend
./activate.sh frontend "Monitoring dashboard UI:
- ServiceGrid: cards showing service name, health dot (green/yellow/red), uptime
- LatencyChart: timeseries with p50/p95/p99 lines (recharts or chart.js)
- ErrorRateGraph: bar chart with threshold line
- LogViewer: virtualized list, filters by level/service, text search, syntax highlight
- AlertRuleEditor: form to create/edit alert rules
Dark theme. Auto-refresh via WebSocket. Keyboard shortcuts for power users."

# 4 — Security + QA (parallel)
./activate.sh sec "Dashboard security: internal-only access enforcement (SSO/VPN), what log data is exposed (PII scrubbing), alert rule injection prevention, API authentication (service accounts vs user tokens), audit log for alert rule changes."

./activate.sh qa "Dashboard test plan:
- Metric accuracy: compare dashboard values with direct Prometheus queries
- Log search performance: 10M+ log entries, search latency < 2s
- WebSocket: reconnection on network drop, data consistency on reconnect
- Dashboard load time: < 2s for 30-day metric range
- Alert rule CRUD: create, trigger, resolve, delete flow
- Accessibility: keyboard navigation through all panels"
```

---

## Supervisor Mode

Instead of deciding which pods to activate yourself, load the Supervisor as the AI's system prompt and just describe your wish.

**How to use:**
1. Open Claude (or any AI chat)
2. Set the contents of `agents/SUPERVISOR.md` as the system prompt
3. Type your wish

**Example input:**
```
I want to build a SaaS with user authentication, Stripe billing (free/pro plans),
a team management feature (invite members, roles), and a usage analytics dashboard.
```

**The Supervisor responds with the full execution plan:**
```
## Execution Plan

### Step 1 — PO (run first)
Command:
./activate.sh po "Define user stories for: auth system, Stripe billing with
free/pro plans, team management (invite, roles), usage analytics dashboard.
3-phase MVP roadmap."

### Step 2 — Parallel execution
Command A:
./activate.sh backend "..."

Command B:
./activate.sh frontend "..."

### Step 3 — Validation (parallel)
Command A:
./activate.sh qa "..."

Command B:
./activate.sh sec "..."

### Step 4 — Infrastructure
Command:
./activate.sh devops "..."

Pods involved: po, backend, frontend, qa, sec, devops
Total steps: 4 (2 parallel stages)
```

Then you run each command, paste the output into the AI, and collect the artifacts.

---

## Memory System

Every time you run `activate.sh`, it appends the task to the pod's `memory.md`:

```markdown
## Tarefa Executada em 2026-03-18 10:30:00
**Task**: Define user stories for registration and login

## Tarefa Executada em 2026-03-19 09:15:00
**Task**: Add social login stories (Google, GitHub) to Phase 2
```

On the next activation, the AI sees the full history — previous decisions, implemented features, defined schemas — and continues with full context.

To reset a pod's memory, clear the content of `memory.md` (keep the file).

---

## Output Artifacts

Each pod produces structured outputs saved to its `context/` directory:

| Pod | Artifacts |
|-----|-----------|
| `po` | `context/user_stories.md`, `context/roadmap.md`, `context/decisions.md` |
| `backend` | `context/api_specs.md`, `context/schemas.md`, `context/services.md` |
| `frontend` | `context/components.md`, `context/pages.md`, `context/design_tokens.md` |
| `qa` | `context/test_plans.md`, `context/bugs.md`, `context/test_results.md` |
| `sec` | `context/security_reviews.md`, `context/vulnerabilities.md`, `context/policies.md` |
| `devops` | `context/pipelines.md`, `context/docker.md`, `context/infrastructure.md`, `context/monitoring.md` |

---

## License

MIT
