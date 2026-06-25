# AgentWatch

An event-driven AI agent platform on GCP. Listens to Gmail, Slack, and Calendar events, routes them through a Claude-powered agent, and streams every reasoning step and tool call to a real-time UI.

```
Event source → Cloud Functions → Pub/Sub → Cloud Run (agent) → Firestore + SSE → Next.js UI
```

## Repositories at a glance

| Path | What it does |
|---|---|
| `infra/terraform/` | All GCP infrastructure as Terraform |
| `services/ingest/` | Cloud Functions webhook handler |
| `services/agent/` | Cloud Run agent service (Claude + MCP) |
| `services/frontend/` | Next.js UI (sidebar, topbar, live trace) |
| `docs/` | Architecture decisions and runbooks |
| `.github/workflows/` | CI/CD pipelines |

## Prerequisites

- GCP project with billing enabled
- `gcloud` CLI authenticated
- Terraform ≥ 1.7
- Node.js 20+
- Anthropic API key

## Quick start

```bash
# 1. Provision infrastructure
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # fill in your values
terraform init && terraform apply

# 2. Deploy ingest function
cd ../../services/ingest
npm install
gcloud functions deploy agentwatch-ingest \
  --gen2 --runtime nodejs20 --trigger-http --allow-unauthenticated

# 3. Deploy agent service
cd ../agent
npm install
gcloud run deploy agentwatch-agent \
  --source . --region us-central1 --allow-unauthenticated

# 4. Deploy frontend
cd ../frontend
npm install && npm run build
gcloud run deploy agentwatch-frontend \
  --source . --region us-central1 --allow-unauthenticated
```

## Documentation

- [Architecture](docs/architecture.md)
- [Infrastructure](docs/infrastructure.md)
- [Local development](docs/local-dev.md)
- [Adding a new event source](docs/adding-event-sources.md)

## Project status

- [x] Repository scaffold + IaC
- [x] Cloud Functions ingest handler
- [ ] Cloud Run agent service
- [ ] Next.js frontend
- [ ] CI/CD pipelines
