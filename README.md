# Dev-IA-Team

> I built my own AI team inside Claude.

This repository implements a **complete software engineering team powered by AI agents**. Each agent (called a **pod**) has a specialized role, persistent memory, and structured output — all coordinated by a central **Supervisor**.

You give a high-level wish. The Supervisor breaks it down. The pods execute. You get production-grade artifacts from an entire team.

---

## Architecture

```
agents/
├── SUPERVISOR.md              # The orchestrator — routes tasks to pods
├── activate.sh                # Activates a pod with context + memory
└── pods/
    ├── po/                    # Product Owner
    │   ├── PROMPT.md          #   Role, skills, output formats
    │   └── memory.md          #   Persistent context & task history
    ├── backend/               # Backend Developers
    │   ├── PROMPT.md
    │   └── memory.md
    ├── frontend/              # Frontend Developers
    │   ├── PROMPT.md
    │   └── memory.md
    ├── qa/                    # Quality Assurance
    │   ├── PROMPT.md
    │   └── memory.md
    ├── sec/                   # Security Engineers
    │   ├── PROMPT.md
    │   └── memory.md
    └── devops/                # DevOps Analysts
        ├── PROMPT.md
        └── memory.md
```

## The Team

| Pod | Role | Skills |
|-----|------|--------|
| **po** | Product Owner | User stories, MoSCoW prioritization, roadmap, stakeholder management, MVP definition |
| **backend** | Backend Developers | REST/GraphQL APIs, microservices, SQL/NoSQL databases, auth, caching, OpenAPI docs |
| **frontend** | Frontend Developers | React/Vue/Angular components, state management, Tailwind/CSS-in-JS, WCAG accessibility |
| **qa** | Quality Assurance | Test plans, bug triage, automation (unit/integration/E2E), coverage analysis, quality gates |
| **sec** | Security Engineers | OWASP Top 10, OAuth2/JWT/SAML, code review, vulnerability assessment, LGPD/GDPR compliance |
| **devops** | DevOps Analysts | GitHub Actions/GitLab CI, Docker/K8s, Terraform/Pulumi, Prometheus/Grafana, AWS/GCP/Azure |

---

## How It Works

```
                         ┌─────────────────────────────┐
                         │     YOU give a "wish"        │
                         │  "I want a SaaS with auth"   │
                         └─────────────┬───────────────┘
                                       ▼
                         ┌─────────────────────────────┐
                         │        SUPERVISOR            │
                         │  Analyzes → Plans → Routes   │
                         └─────────────┬───────────────┘
                                       ▼
              ┌────────────────────────────────────────────────┐
              │          Task Distribution                      │
              │  (parallel when independent, sequential when    │
              │   there are dependencies between pods)          │
              └────────────────────────────────────────────────┘
                    │         │         │         │        │
                    ▼         ▼         ▼         ▼        ▼
                 ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐
                 │ PO  │  │ BE  │  │ FE  │  │ QA  │  │ Sec │ ...
                 └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘
                    │         │         │         │        │
                    ▼         ▼         ▼         ▼        ▼
              ┌────────────────────────────────────────────────┐
              │     SUPERVISOR aggregates & delivers            │
              └────────────────────────────────────────────────┘
```

Each pod activation:
1. Loads `PROMPT.md` (role + instructions + output templates)
2. Loads `memory.md` (full project history and decisions)
3. Receives and executes the task with complete context
4. Appends the task to `memory.md` with a timestamp

Memory is persistent — every pod remembers everything it has done across sessions.

---

## Examples: From Wish to Full Team Execution

Below are real-world examples of how a single "wish" triggers the entire team in a coordinated chain.

---

### Example 1: "I want a user authentication system"

**Your wish:**
> "Build a complete user authentication system with login, registration, password recovery, and social login."

**Supervisor breaks it down — full chain:**

```
Step 1 ─ PO (Product Owner)
│  "Create user stories for authentication: login, registration,
│   password recovery, and social login (Google/GitHub).
│   Define MVP scope and prioritize with MoSCoW."
│
│  Output: User stories (US-001 to US-008), MVP roadmap,
│          acceptance criteria for each story
│
Step 2 ─ BACKEND + FRONTEND (parallel — no dependency between them)
│
│  backend:
│  │  "Design and implement the auth API: POST /auth/register,
│  │   POST /auth/login, POST /auth/forgot-password,
│  │   POST /auth/reset-password, GET /auth/oauth/google,
│  │   GET /auth/oauth/github. Use JWT + refresh tokens.
│  │   Define the Users table schema with bcrypt passwords."
│  │
│  │  Output: API specs (OpenAPI), DB schema (users, sessions,
│  │          oauth_providers), AuthService definition, JWT flow
│  │
│  frontend:
│     "Build the auth UI: LoginForm, RegisterForm,
│      ForgotPasswordForm, ResetPasswordForm, SocialLoginButton.
│      Use React + Tailwind. Include loading, error, and success
│      states. Ensure WCAG 2.1 AA accessibility."
│
│     Output: Component specs with props/states, page layouts
│             (LoginPage, RegisterPage), design tokens, ARIA labels
│
Step 3 ─ QA (Quality Assurance)
│  "Create a test plan for the auth system. Cover:
│   - Unit tests for AuthService (register, login, token refresh)
│   - Integration tests for all API endpoints
│   - E2E tests for the complete login/register flows
│   - Edge cases: expired tokens, invalid passwords, duplicate emails
│   - Define quality gates: 80% coverage, 0 critical bugs."
│
│  Output: Test plan, test cases (30+), automation scripts,
│          quality gate definitions
│
Step 4 ─ SEC (Security)
│  "Security review of the auth system. Check:
│   - OWASP Top 10 (injection, broken auth, XSS)
│   - JWT implementation (algorithm, expiration, refresh rotation)
│   - Password policy (bcrypt rounds, complexity rules)
│   - OAuth flow (PKCE, state parameter, redirect validation)
│   - Rate limiting on login/register endpoints
│   - LGPD compliance for user data storage."
│
│  Output: Security review report, vulnerability list,
│          OWASP checklist, mitigation recommendations
│
Step 5 ─ DEVOPS
   "Set up CI/CD for the auth service:
    - Dockerfile (multi-stage, non-root user)
    - GitHub Actions pipeline (build, test, security scan, deploy)
    - Quality gates in the pipeline
    - Monitoring alerts for failed logins and auth errors."

   Output: Dockerfile, pipeline YAML, monitoring alerts,
           environment variables config
```

**Activate it step by step:**

```bash
./activate.sh po "Create user stories for auth: login, registration, password recovery, social login. Define MVP and prioritize with MoSCoW."

./activate.sh backend "Design auth API: register, login, forgot-password, reset-password, OAuth Google/GitHub. JWT + refresh tokens. Define Users schema."

./activate.sh frontend "Build auth UI components: LoginForm, RegisterForm, ForgotPasswordForm, SocialLoginButton. React + Tailwind, WCAG 2.1 AA."

./activate.sh qa "Create test plan for auth: unit, integration, E2E. Cover edge cases (expired tokens, duplicate emails). Quality gate: 80% coverage."

./activate.sh sec "Security review: OWASP Top 10, JWT implementation, password policy, OAuth PKCE flow, rate limiting, LGPD compliance."

./activate.sh devops "CI/CD for auth service: Dockerfile multi-stage, GitHub Actions pipeline, quality gates, monitoring alerts for auth failures."
```

---

### Example 2: "I want a real-time chat system"

**Your wish:**
> "Build a real-time chat with direct messages, group channels, typing indicators, and file sharing."

**Supervisor chain:**

```
Step 1 ─ PO
│  Task: "Define user stories for real-time chat: DMs, group channels,
│         typing indicators, file sharing, message history.
│         Prioritize MVP (DMs + channels first, files later)."
│  Output: 12 user stories, MVP vs Phase 2 split, acceptance criteria
│
Step 2 ─ BACKEND
│  Task: "Design chat backend: WebSocket server for real-time messaging,
│         REST API for history/channels/users. Design schemas for
│         messages, channels, channel_members. Implement Redis pub/sub
│         for horizontal scaling. File upload to S3 with presigned URLs."
│  Output: WebSocket event specs, REST API specs, DB schemas,
│          MessageService, ChannelService, FileService, Redis pub/sub flow
│
Step 3 ─ FRONTEND (after backend — needs WebSocket contract)
│  Task: "Build chat UI: ChatWindow, MessageBubble, ChannelList,
│         ChannelHeader, TypingIndicator, FileUploadButton, MessageInput.
│         Implement WebSocket connection with auto-reconnect.
│         State management for messages, channels, online users."
│  Output: 8 component specs, WebSocket hook, state architecture,
│          responsive layout for mobile/desktop
│
Step 4 ─ QA + SEC (parallel — independent reviews)
│
│  qa:
│  │  Task: "Test plan for chat: WebSocket connection stability,
│  │         message ordering, typing indicator timing, file upload
│  │         limits, concurrent users load test (1000+ connections)."
│  │  Output: Test plan, load test scenarios, WebSocket test cases
│  │
│  sec:
│     Task: "Review chat security: WebSocket auth (token in handshake),
│            message sanitization (XSS prevention), file upload validation
│            (type/size/malware), channel authorization, rate limiting,
│            encryption at rest and in transit."
│     Output: Security review, 6 vulnerability findings, mitigations
│
Step 5 ─ DEVOPS
   Task: "Infrastructure for chat: Dockerize backend + WebSocket server,
          K8s deployment with HPA for auto-scaling, Redis cluster config,
          S3 bucket for files, Prometheus metrics for WebSocket connections,
          Grafana dashboard, alerts for connection drops > 5%."
   Output: Dockerfile, K8s manifests, Terraform for Redis + S3,
           monitoring config, alert rules
```

---

### Example 3: "I want an e-commerce platform"

**Your wish:**
> "Build an e-commerce with product catalog, shopping cart, checkout with Stripe, and order tracking."

**Supervisor chain:**

```
Step 1 ─ PO
│  Task: "User stories for e-commerce: product browsing, search with
│         filters, shopping cart, checkout with Stripe, order history,
│         order status tracking. Define MVP scope."
│  Output: 20 user stories across 3 epics, MVP roadmap (3 phases)
│
Step 2 ─ BACKEND + FRONTEND (parallel)
│
│  backend:
│  │  Task: "E-commerce APIs: products CRUD with search/filters,
│  │         cart management, Stripe checkout session + webhooks,
│  │         order lifecycle (pending → paid → shipped → delivered).
│  │         Schemas: products, cart_items, orders, order_items, payments."
│  │  Output: 15 API endpoints, 5 DB schemas, Stripe integration flow,
│  │          ProductService, CartService, OrderService, PaymentService
│  │
│  frontend:
│     Task: "E-commerce UI: ProductGrid, ProductCard, ProductDetail,
│            SearchBar with filters, CartDrawer, CartItem,
│            CheckoutForm (Stripe Elements), OrderTimeline.
│            Responsive, mobile-first. SSR for product pages (SEO)."
│     Output: 10 component specs, 5 page layouts, SEO strategy,
│             Stripe Elements integration, responsive breakpoints
│
Step 3 ─ SEC
│  Task: "Security review of e-commerce: Stripe webhook signature
│         validation, PCI DSS awareness (no card data stored),
│         SQL injection on search/filter, price tampering prevention
│         (server-side validation), CSRF on checkout, rate limiting."
│  Output: Security review, PCI compliance notes, 4 critical findings
│
Step 4 ─ QA
│  Task: "Test plan: product search accuracy, cart operations
│         (add/remove/update/empty), complete checkout flow with
│         Stripe test mode, order status transitions, payment failure
│         handling, concurrent cart updates, inventory race conditions."
│  Output: Test plan, 45 test cases, Stripe test card scenarios
│
Step 5 ─ DEVOPS
   Task: "E-commerce infra: Dockerize services, GitHub Actions with
          staging → production promotion, Stripe webhook endpoint
          in each env, CDN for product images, auto-scaling based on
          traffic, monitoring for payment failures and order errors."
   Output: Docker Compose, CI/CD pipeline, CDN config,
           Terraform for staging + prod, alerting rules
```

---

### Example 4: "I want a monitoring dashboard for my microservices"

**Your wish:**
> "Build an internal dashboard to monitor health, latency, error rates, and logs for all our microservices."

**Supervisor chain:**

```
Step 1 ─ PO
│  Task: "Define requirements for an internal observability dashboard:
│         service health overview, latency percentiles (p50/p95/p99),
│         error rate trends, log search, alerting rules config.
│         Users: SRE team + on-call engineers."
│  Output: 8 user stories, persona definitions, alert configuration stories
│
Step 2 ─ BACKEND + DEVOPS (parallel)
│
│  backend:
│  │  Task: "Dashboard API: aggregate metrics from Prometheus (health,
│  │         latency, error rates), proxy log queries to Loki/ELK,
│  │         CRUD for alert rules, WebSocket for live metric updates.
│  │         Service registry integration for auto-discovery."
│  │  Output: API specs, MetricsService, LogService, AlertService,
│  │          WebSocket event specs, service discovery flow
│  │
│  devops:
│     Task: "Observability stack: Prometheus + Grafana for metrics,
│            Loki for logs, Alertmanager for alerts. Terraform modules
│            for the stack. Service mesh sidecar config for automatic
│            metric collection. Define SLIs/SLOs for each service."
│     Output: Terraform modules, Prometheus config, Grafana provisioning,
│             Alertmanager rules, SLI/SLO definitions
│
Step 3 ─ FRONTEND
│  Task: "Dashboard UI: ServiceGrid (health cards with status dots),
│         LatencyChart (p50/p95/p99 timeseries), ErrorRateGraph,
│         LogViewer (searchable, filterable, syntax highlighted),
│         AlertRuleEditor. Dark theme. Auto-refresh with WebSocket."
│  Output: 7 component specs, dashboard layout, dark theme tokens,
│          WebSocket integration, chart library selection
│
Step 4 ─ SEC + QA (parallel)
│
│  sec:
│     Task: "Review dashboard security: internal-only access (VPN/SSO),
│            log data exposure risks, alert rule injection prevention,
│            API authentication (service accounts vs user tokens)."
│     Output: Access control recommendations, 3 findings
│
│  qa:
│     Task: "Test plan: metric accuracy validation, log search performance
│            (10M+ entries), WebSocket reconnection, dashboard load time
│            under 2s, alert rule CRUD operations, mobile responsiveness."
│     Output: Test plan, performance benchmarks, 20 test cases
```

---

## Orchestration Patterns

The Supervisor uses three patterns to coordinate pods:

### Parallel
Independent pods run simultaneously. No dependency between them.
```
PO ──────────┐
Backend ─────┼──→ Supervisor aggregates
Frontend ────┘
```

### Sequential
Pods with dependencies run in order. Each step feeds the next.
```
PO → Backend → Frontend → QA → Sec → DevOps
```

### Hybrid (most common)
Some pods run in parallel, some wait for dependencies.
```
PO → [Backend ║ Frontend] → [QA ║ Sec] → DevOps
       (parallel)            (parallel)
```

---

## Usage

### Option 1: Supervisor Mode (recommended)

Load `agents/SUPERVISOR.md` as the system prompt in your AI session (Claude, ChatGPT, etc.), then give your wish:

> "I want a SaaS with user auth, billing with Stripe, and a team management dashboard."

The Supervisor will output:
- Which pods to activate and in what order
- The specific task for each pod
- Dependencies between steps
- Expected artifacts from each pod

Then activate each pod in the order the Supervisor defined.

### Option 2: Direct Pod Activation

```bash
cd agents
./activate.sh <pod> "<task>"
```

The script:
1. Validates the pod exists
2. Loads system prompt (`PROMPT.md`) and context (`memory.md`)
3. Displays everything for the AI to consume
4. Logs the task to memory with a timestamp

### Option 3: Full Chain Script

Run the entire chain manually for a feature:

```bash
# Step 1: Product Owner defines the work
./activate.sh po "Define user stories and MVP scope for a payment system with Stripe"

# Step 2: Backend and Frontend in parallel
./activate.sh backend "Implement Stripe checkout API: create session, handle webhooks, store payment records"
./activate.sh frontend "Build CheckoutPage with Stripe Elements, PaymentHistory component, InvoiceDownload"

# Step 3: QA and Security in parallel
./activate.sh qa "Test plan for payments: successful charge, declined card, webhook retry, refund flow"
./activate.sh sec "Review Stripe integration: webhook signature, PCI compliance, no card data logged"

# Step 4: DevOps wraps it up
./activate.sh devops "Add payment service to CI/CD: Stripe test mode in staging, production webhook config"
```

---

## Memory System

Each pod's `memory.md` is an append-only log that grows over time:

```markdown
## Tarefa Executada em 2026-03-18 10:30:00
**Task**: Create user stories for auth

## Tarefa Executada em 2026-03-18 11:15:00
**Task**: Define MVP roadmap for Phase 1

## Tarefa Executada em 2026-03-18 14:00:00
**Task**: Add social login stories (Google, GitHub)
```

This means:
- **Continuity**: pods remember all previous decisions and context
- **Audit trail**: full history of what was requested and when
- **Context loading**: on each activation, the AI receives the entire history

To reset a pod's memory, clear the content of its `memory.md` (keep the file).

---

## Output Artifacts

Each pod generates structured, standardized outputs:

| Pod | Format | Artifacts |
|-----|--------|-----------|
| **po** | User stories (COMO/PRECISO/PARA), MoSCoW | `context/user_stories.md`, `context/roadmap.md`, `context/decisions.md` |
| **backend** | OpenAPI specs, SQL schemas, service definitions | `context/api_specs.md`, `context/schemas.md`, `context/services.md` |
| **frontend** | Component specs (atomic design), page layouts | `context/components.md`, `context/design_tokens.md`, `context/pages.md` |
| **qa** | Test plans, bug reports, test results | `context/test_plans.md`, `context/bugs.md`, `context/test_results.md` |
| **sec** | OWASP checklists, vulnerability reports | `context/security_reviews.md`, `context/vulnerabilities.md`, `context/policies.md` |
| **devops** | Pipeline YAML, Dockerfiles, Terraform, alerts | `context/pipelines.md`, `context/docker.md`, `context/infrastructure.md`, `context/monitoring.md` |

---

## Requirements

- **Bash** (for `activate.sh`)
- **An AI assistant** (Claude, ChatGPT, or any LLM) to execute the loaded context

No dependencies. No API keys. No setup. Just clone and start activating pods.

```bash
git clone https://github.com/thespamer/Dev-IA-Team.git
cd Dev-IA-Team/agents
./activate.sh po "Your first task here"
```

---

## License

MIT
