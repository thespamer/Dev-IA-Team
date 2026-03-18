# Dev-IA-Team

A framework to simulate a complete software engineering team using AI agents, each with a defined role, persistent memory, and context — orchestrated by a central Supervisor.

## Architecture

```
agents/
├── SUPERVISOR.md          # Central orchestrator
├── activate.sh            # Pod activation script
└── pods/
    ├── po/                # Product Owner
    ├── backend/           # Backend Developers
    ├── frontend/          # Frontend Developers
    ├── qa/                # Quality Assurance
    ├── sec/               # Security Engineers
    └── devops/            # DevOps Analysts
```

Each pod contains:
- `PROMPT.md` — system instructions defining the agent's role, skills, and output formats
- `memory.md` — persistent context: project decisions, implemented features, task history

## How It Works

```
User assigns task to Supervisor
         ↓
Supervisor analyzes and identifies required pods
         ↓
Pods execute (in parallel or sequence)
         ↓
Results are aggregated and delivered
```

When a pod is activated via `activate.sh`:
1. The pod's `PROMPT.md` (role + instructions) is loaded
2. The pod's `memory.md` (persistent context) is loaded
3. The task is passed to the agent with full context
4. The task is appended to `memory.md` with a timestamp

This ensures continuity across sessions — every pod remembers what it has done.

## Pods

| Pod | Role | Responsibilities |
|-----|------|-----------------|
| `po` | Product Owner | Roadmap, user stories (MoSCoW), stakeholder management |
| `backend` | Backend Developers | APIs, microservices, databases, business logic |
| `frontend` | Frontend Developers | UI/UX components, state management, accessibility |
| `qa` | Quality Assurance | Test planning, automation, bug triage, quality gates |
| `sec` | Security Engineers | OWASP, auth/authz, vulnerability assessment, code review |
| `devops` | DevOps Analysts | CI/CD pipelines, containers, IaC, monitoring |

## Usage

### Activate a pod directly

```bash
cd agents
./activate.sh <pod-name> "<task>"
```

Examples:

```bash
./activate.sh po "Create user stories for the authentication feature"
./activate.sh backend "Implement GET /api/v1/users endpoint"
./activate.sh frontend "Build the login component"
./activate.sh qa "Write regression tests for the auth module"
./activate.sh sec "Review the authentication API for OWASP vulnerabilities"
./activate.sh devops "Set up CI/CD pipeline for the backend service"
```

### Use the Supervisor

Open `agents/SUPERVISOR.md` as the system prompt for your AI session and assign a task. The Supervisor will identify which pods to activate, coordinate execution, and aggregate results.

## Memory & Context

Each pod maintains its state in `memory.md`. This file is automatically updated with every task execution, creating an append-only audit trail. On the next invocation, the agent has full access to the project history.

To reset a pod's memory, clear the content of its `memory.md` while keeping the file.

## Orchestration Patterns

- **Parallel**: Independent pods run simultaneously (e.g., backend + frontend for a new feature)
- **Sequential**: Pods with dependencies run in order (e.g., PO defines stories → backend implements → QA tests → sec reviews)
- **Cross-validation**: Security and QA review outputs from other pods before delivery

## Output Artifacts

Each pod generates structured outputs in its own format:

| Pod | Artifacts |
|-----|-----------|
| `po` | User stories, roadmap, product decisions |
| `backend` | API specs, DB schemas, service definitions |
| `frontend` | Component specs, page layouts, design tokens |
| `qa` | Test plans, bug reports, test results |
| `sec` | Security reviews, vulnerability reports, policies |
| `devops` | Pipeline configs, Dockerfiles, infrastructure specs |

Artifacts are saved to each pod's `context/` directory.

## Requirements

- Bash (for `activate.sh`)
- An AI assistant (Claude or any LLM) to execute the loaded context and tasks

## License

MIT
