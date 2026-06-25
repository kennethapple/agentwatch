# AgentWatch

Event-driven AI agent platform on GCP. Listens to Gmail, Slack, and Calendar,
routes each event through a Claude-powered agent, and streams every reasoning
step and tool call to a real-time browser UI.

```
Gmail / Slack / Calendar
        │  webhooks
        ▼
Cloud Functions (ingest)   ← normalize + validate
        │  Pub/Sub
        ▼
Cloud Run (agent)          ← Claude streaming + MCP tools
        │  SSE + Firestore
        ▼
Next.js UI                 ← live agent trace
```

**Project:** `boreal-phoenix-405421` · **Region:** `us-central1`
**Repo:** `kennethapple/agentwatch`

---

## Quick start

```bash
# 1. Bootstrap GCP (once)
chmod +x infra/bootstrap.sh && ./infra/bootstrap.sh

# 2. Apply infrastructure
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars  # fill in secrets
terraform init && terraform apply

# 3. Add GitHub Actions secrets (printed by bootstrap.sh + terraform output)
#    GCP_PROJECT_ID, GCP_WORKLOAD_IDENTITY_PROVIDER, GCP_DEPLOY_SA
#    ANTHROPIC_API_KEY, SLACK_SIGNING_SECRET, GMAIL_WEBHOOK_TOKEN

# 4. Trigger first deploy
git commit --allow-empty -m "ci: trigger initial deploy" && git push

# 5. Connect Gmail
GMAIL_ADDRESS=you@example.com ./infra/scripts/setup-gmail-watch.sh

# 6. Connect Slack
./infra/scripts/setup-slack-app.sh
```

Full walkthrough: **[docs/deployment.md](docs/deployment.md)**

---

## Repository layout

```
infra/
  bootstrap.sh              ← run once: GCS bucket + WIF setup
  terraform/                ← all GCP resources as Terraform
    main.tf                 ← provider, GCS backend, API enablement
    variables.tf            ← all input variables (with defaults)
    wif.tf                  ← Workload Identity Federation + deploy SA
    iam.tf                  ← per-service service accounts + bindings
    pubsub.tf               ← events topic + agent push subscription
    firestore.tf            ← database + composite indexes
    cloudrun.tf             ← agent + frontend Cloud Run services
    functions.tf            ← Gmail + Slack Cloud Functions
    secrets.tf              ← Secret Manager secrets
    outputs.tf              ← URLs, WIF values for GitHub secrets
  scripts/
    setup-gmail-watch.sh    ← register gmail.users.watch post-deploy
    setup-slack-app.sh      ← print Slack Event Subscriptions URL

services/
  ingest/                   ← Cloud Functions webhook handlers
  agent/                    ← Cloud Run: Claude streaming + MCP + SSE
  frontend/                 ← Next.js: sidebar + live agent trace

docs/
  deployment.md             ← end-to-end deployment guide ← START HERE
  architecture.md           ← system design + data flow
  infrastructure.md         ← Terraform reference
  local-dev.md              ← running services locally
  adding-event-sources.md   ← how to add new webhook sources

.github/workflows/
  ci.yml                    ← test + lint + terraform validate on PRs
  terraform.yml             ← plan on PR, apply on merge to main
  deploy.yml                ← build + deploy services on merge to main
```

## CI/CD

| Trigger | Workflow | What runs |
|---|---|---|
| PR to `main` | `ci.yml` | Tests, lint, terraform validate |
| PR to `main` (infra changes) | `terraform.yml` | `terraform plan` posted as PR comment |
| Push to `main` (infra changes) | `terraform.yml` | `terraform apply` |
| Push to `main` (agent changes) | `deploy.yml` | Build image → Cloud Run |
| Push to `main` (frontend changes) | `deploy.yml` | Build image → Cloud Run |
| Push to `main` (ingest changes) | `deploy.yml` | Re-deploy Cloud Functions |

## Documentation

- [Deployment guide](docs/deployment.md) — step-by-step to go live
- [Architecture](docs/architecture.md) — component design + data flow
- [Infrastructure](docs/infrastructure.md) — Terraform resource reference
- [Local development](docs/local-dev.md) — run services locally
- [Adding event sources](docs/adding-event-sources.md) — extend to new webhooks

## Status

- [x] GCP infrastructure (Terraform)
- [x] Workload Identity Federation (keyless CI/CD auth)
- [x] Cloud Functions ingest — Gmail + Slack
- [x] Cloud Run agent — Claude streaming + MCP + SSE
- [x] Next.js frontend — live agent trace
- [x] GitHub Actions — CI, terraform plan/apply, deploy pipelines
- [x] Deployment runbook
- [ ] Calendar event source
- [ ] Run history page
- [ ] Cloud Scheduler for Gmail watch renewal
