# AgentWatch

Event-driven AI agent platform on GCP. Listens to Gmail and Slack,
routes each event through a Claude-powered agent, and streams every reasoning
step and tool call to a real-time browser UI.

```
Gmail / Slack
      │  webhooks
      ▼
Cloud Functions (ingest)   ← normalize + validate → CommonJS, Node 20
      │  Pub/Sub
      ▼
Cloud Run (agent)          ← Claude streaming + MCP tools + SSE
      │  Firestore + SSE
      ▼
Next.js UI (frontend)      ← live agent trace, event list
```

**Project:** `boreal-phoenix-405421` · **Region:** `us-central1`
**Repo:** `kennethapple/agentwatch`

---

## Status

### Live ✅
- GCP infrastructure — fully provisioned via Terraform
- Workload Identity Federation — keyless GitHub Actions auth
- CI/CD pipelines — test, lint, terraform plan/apply, build + deploy
- Cloud Functions — Gmail + Slack ingest handlers deployed
- Cloud Run — agent service + frontend deployed
- Firestore — database live, indexes managed by Terraform
- Secret Manager — all credentials stored, mounted at runtime

### Up next
- [ ] Connect Gmail — run `setup-gmail-watch.sh`
- [ ] Connect Slack — run `setup-slack-app.sh` and register URL
- [ ] Configure MCP servers — set `MCP_SERVERS` env var on agent Cloud Run
- [ ] Calendar event source
- [ ] Run history page (`/history`)
- [ ] Cloud Scheduler job for weekly Gmail watch renewal

---

## Quick start for a new developer

```bash
git clone https://github.com/kennethapple/agentwatch
cd agentwatch

# 1. Configure local environment
cp infra/config.env infra/config.local.env
# Edit: set GCP_PROJECT_ID=boreal-phoenix-405421 and GITHUB_REPO=kennethapple/agentwatch

# 2. Authenticate
gcloud auth login
gcloud config set project boreal-phoenix-405421

# 3. Connect your event sources
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh
./infra/scripts/setup-slack-app.sh
```

**Infrastructure is already live.** Bootstrap and `terraform apply` have been
run. New developers do not need to repeat those steps.

Full walkthrough: **[docs/deployment.md](docs/deployment.md)**

---

## Making changes

```bash
# Any push to main auto-deploys the changed service(s)
git add . && git commit -m "your change" && git push origin main

# Trigger a terraform apply manually
./infra/scripts/trigger-terraform.sh
```

CI runs on every push. The deploy workflow detects which service changed
and only rebuilds that one.

---

## Repository layout

```
infra/
  bootstrap.sh              ← run once per project (already done)
  config.env                ← config template — copy to config.local.env
  terraform/
    main.tf                 ← provider, GCS backend, API enablement
    variables.tf            ← input variables (project_id defaults set)
    wif.tf                  ← Workload Identity Federation + deploy SA
    iam.tf                  ← per-service service accounts + bindings
    pubsub.tf               ← events topic + agent push subscription
    firestore.tf            ← Firestore indexes (database managed outside TF)
    cloudrun.tf             ← agent + frontend Cloud Run services
    functions.tf            ← Gmail + Slack Cloud Functions
    secrets.tf              ← Secret Manager secrets
    outputs.tf              ← service URLs, WIF values
  scripts/
    setup-gmail-watch.sh    ← register gmail.users.watch
    setup-slack-app.sh      ← print Slack Event Subscriptions URL
    trigger-terraform.sh    ← pull + touch + push to trigger terraform CI

services/
  ingest/                   ← Cloud Functions (CommonJS, Node 20)
  agent/                    ← Cloud Run: Claude streaming + MCP + SSE
  frontend/                 ← Next.js 14: sidebar + live agent trace

docs/
  deployment.md             ← end-to-end guide + new developer onboarding
  architecture.md           ← system design + data flow
  infrastructure.md         ← Terraform reference
  local-dev.md              ← running services locally
  adding-event-sources.md   ← how to extend with new webhook sources

.github/workflows/
  ci.yml                    ← test + lint + terraform validate (PRs)
  terraform.yml             ← plan on PR, apply on merge to main
  deploy.yml                ← path-filtered build + deploy on merge to main
```

---

## CI/CD

| Trigger | Workflow | What runs |
|---|---|---|
| PR to `main` | `ci.yml` | Tests, lint, terraform validate |
| PR to `main` (infra changes) | `terraform.yml` | `terraform plan` posted as PR comment |
| Push to `main` (infra changes) | `terraform.yml` | `terraform apply` |
| Push to `main` (agent changes) | `deploy.yml` | Build + push image → Cloud Run |
| Push to `main` (frontend changes) | `deploy.yml` | Build + push image → Cloud Run |
| Push to `main` (ingest changes) | `deploy.yml` | Re-deploy Cloud Functions |

---

## Documentation

- [Deployment guide](docs/deployment.md) — onboarding + operations runbook
- [Architecture](docs/architecture.md) — component design + data flow
- [Infrastructure](docs/infrastructure.md) — Terraform resource reference
- [Local development](docs/local-dev.md) — running services locally
- [Adding event sources](docs/adding-event-sources.md) — extending to new webhooks

---

## Known issues / gotchas

- **Firestore database** is not managed by Terraform (GCP does not support
  deleting Firestore databases, so full lifecycle management is not possible).
  The database was created during initial setup and is permanent.

- **Gmail watch expires every 7 days.** Re-run `setup-gmail-watch.sh` weekly,
  or set up a Cloud Scheduler job (see deployment.md).

- **gcloud Python compatibility:** gcloud requires Python 3.8–3.12.
  If you get a Python version error, set `CLOUDSDK_PYTHON` to point at a
  compatible version: `export CLOUDSDK_PYTHON=$(which python3.12)`
