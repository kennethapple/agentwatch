# Deployment guide

## Current state

**Infrastructure is live.** The initial deployment is complete. Most developers
joining this project do not need to follow the first-time setup steps.

| Component | Status | URL |
|---|---|---|
| Agent (Cloud Run) | ✅ Live | `terraform output agent_url` |
| Frontend (Cloud Run) | ✅ Live | `terraform output frontend_url` |
| Gmail ingest (Cloud Functions) | ✅ Live | Needs `setup-gmail-watch.sh` |
| Slack ingest (Cloud Functions) | ✅ Live | Needs Slack app URL registration |
| Firestore | ✅ Live | `(default)` database, us-central1 |
| Pub/Sub | ✅ Live | `agentwatch-events` topic |
| Secret Manager | ✅ Live | 3 secrets provisioned |
| Artifact Registry | ✅ Live | `us-central1-docker.pkg.dev/boreal-phoenix-405421/agentwatch` |

---

## Joining an existing deployment

```bash
git clone https://github.com/kennethapple/agentwatch
cd agentwatch

# 1. Configure local environment
cp infra/config.env infra/config.local.env
# Edit: set GCP_PROJECT_ID=boreal-phoenix-405421 and GITHUB_REPO=kennethapple/agentwatch

# 2. Authenticate to GCP
gcloud auth login
gcloud config set project boreal-phoenix-405421

# 3. Connect Gmail (if not already connected, or to renew the 7-day watch)
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh

# 4. Get the Slack ingest URL
./infra/scripts/setup-slack-app.sh
```

That's it. Push to `main` to deploy changes.

---

## Making changes

```bash
# Changes to any service auto-deploy on push to main
git push origin main

# Trigger a terraform apply
./infra/scripts/trigger-terraform.sh
```

---

## First-time setup (reference only — already completed)

These steps were completed during initial project setup. Documented here
for reference if the project ever needs to be rebuilt from scratch.

### Prerequisites

- GCP project Owner access on `boreal-phoenix-405421`
- `gcloud` CLI authenticated
- Terraform ≥ 1.9
- Node.js 20+

### Step 1 — Clone and configure

```bash
git clone https://github.com/kennethapple/agentwatch
cd agentwatch
cp infra/config.env infra/config.local.env
# Set GCP_PROJECT_ID and GITHUB_REPO in config.local.env
```

### Step 2 — Bootstrap

```bash
./infra/bootstrap.sh
```

Creates: GCS tfstate bucket, deploy service account, Workload Identity
Federation pool + provider. Prints 6 values needed for GitHub secrets.

### Step 3 — GitHub Actions secrets

Add at https://github.com/kennethapple/agentwatch/settings/secrets/actions:

| Secret | Source |
|---|---|
| `GCP_PROJECT_ID` | `boreal-phoenix-405421` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | printed by bootstrap.sh |
| `GCP_DEPLOY_SA` | printed by bootstrap.sh |
| `ANTHROPIC_API_KEY` | console.anthropic.com |
| `SLACK_SIGNING_SECRET` | Slack app → Basic Information |
| `GMAIL_WEBHOOK_TOKEN` | printed by bootstrap.sh |

### Step 4 — Terraform

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Fill in: anthropic_api_key, slack_signing_secret, gmail_webhook_token
terraform init
terraform apply
```

### Step 5 — Initial image deploy

```bash
git commit --allow-empty -m "ci: trigger initial deploy"
git push origin main
```

### Step 6 — Connect event sources

```bash
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh
./infra/scripts/setup-slack-app.sh
```

---

## Operations

### Useful commands

```bash
# Get live service URLs
cd infra/terraform && terraform output

# Tail agent logs
gcloud run services logs tail agentwatch-agent \
  --region us-central1 --project boreal-phoenix-405421

# Tail ingest function logs
gcloud functions logs read agentwatch-ingest-gmail \
  --region us-central1 --project boreal-phoenix-405421 --limit 50

# Simulate an event locally
cd services/ingest
AGENT_URL=https://$(gcloud run services describe agentwatch-agent \
  --region us-central1 --project boreal-phoenix-405421 \
  --format='value(status.url)') \
node scripts/simulate.js --source gmail --fixture fixtures/email-approval.json

# Renew Gmail watch (expires every 7 days)
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh

# Manually clear a stale Terraform state lock
gsutil ls gs://boreal-phoenix-405421-agentwatch-tfstate/agentwatch/
gsutil rm gs://boreal-phoenix-405421-agentwatch-tfstate/agentwatch/default.tflock
```

### Gmail watch renewal

The Gmail push notification watch expires every 7 days. Options:

1. **Manual:** `GMAIL_ADDRESS=you@example.com ./infra/scripts/setup-gmail-watch.sh`
2. **Cloud Scheduler (recommended):**
```bash
gcloud scheduler jobs create http agentwatch-gmail-watch-renewal \
  --location us-central1 \
  --project boreal-phoenix-405421 \
  --schedule "0 9 * * MON" \
  --uri "$(gcloud functions describe agentwatch-ingest-gmail \
      --region us-central1 --project boreal-phoenix-405421 \
      --format='value(serviceConfig.uri)')/renew" \
  --message-body '{"renew":true}'
```

---

## Troubleshooting

**`config.local.env not found`**
```bash
cp infra/config.env infra/config.local.env
# edit with your GCP_PROJECT_ID and GITHUB_REPO
```

**GitHub Actions auth fails**
- `GCP_WORKLOAD_IDENTITY_PROVIDER` must start with `projects/` (full resource path)
- `GCP_DEPLOY_SA` must be a full email address ending in `.iam.gserviceaccount.com`

**Terraform state lock error**
```bash
gsutil rm gs://boreal-phoenix-405421-agentwatch-tfstate/agentwatch/default.tflock
./infra/scripts/trigger-terraform.sh
```

**Cloud Functions health check failing**
- Check that `src/index.js` uses `require()` not `import`
- Check that GCP clients (Firestore, Pub/Sub) are lazy-initialized (not at module load time)
- Check that `googleapis` is in `dependencies` (not `@googleapis/gmail`)

**Agent not receiving events**
```bash
gcloud pubsub subscriptions describe agentwatch-agent-sub \
  --project boreal-phoenix-405421
# Verify pushConfig.pushEndpoint matches the agent Cloud Run URL
```

**gcloud Python version error**
```bash
export CLOUDSDK_PYTHON=$(which python3.12)
# Add to ~/.zshrc to make permanent
```
