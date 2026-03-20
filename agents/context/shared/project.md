# Projeto — Contexto Compartilhado

## Identificação

- **Nome do Projeto**: TaskFlow
- **Descrição**: Plataforma de gestão de tarefas para times pequenos (até 20 pessoas), com board kanban, notificações e relatórios de produtividade
- **Repositório**: github.com/taskflow/app
- **Ambiente de produção**: app.taskflow.io

## Stack Tecnológico

| Camada | Tecnologia | Versão |
|--------|-----------|--------|
| Backend | Node.js + Express | 20 LTS |
| Frontend | React + Vite | React 18 |
| Banco de dados | PostgreSQL | 15 |
| Cache | Redis | 7 |
| Infra | AWS ECS + RDS + S3 | — |
| CI/CD | GitHub Actions | — |
| Monitoring | Prometheus + Grafana | — |

## Decisões Arquiteturais

- Auth via JWT RS256, refresh token com rotação, expiração 1h
- Todos os endpoints versionados em /api/v1/
- Soft delete em todas as entidades — campo deleted_at
- IDs no formato UUIDv4

## Padrões de Código

- **Idioma do código**: Inglês
- **Naming convention**: camelCase (JS), snake_case (DB)
- **Formato de datas**: ISO 8601 — YYYY-MM-DDTHH:mm:ssZ
- **Paginação**: cursor-based, padrão limit=20

## Ambientes

| Ambiente | URL | Branch |
|----------|-----|--------|
| Development | localhost:3000 | main |
| Staging | staging.taskflow.io | staging |
| Production | app.taskflow.io | production |

## Status Atual do Projeto

- **Fase**: Discovery
- **Sprint atual**: Sprint 1
- **Próximo milestone**: MVP com auth + board kanban — 30 dias
