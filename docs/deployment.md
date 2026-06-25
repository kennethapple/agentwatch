# Deployment guide

End-to-end steps to go from zero to a live AgentWatch on GCP.
Works for the first developer setting up the project, and for subsequent
developers joining an already-running deployment.

---

## Are you the first developer, or joining an existing deployment?

**First developer** — follow all steps in order.

**Joining an existing deployment** — skip to [Joining an existing deployment](#joining-an-existing-deployment).

---

## Prerequisites

- GCP project access (ask the project owner for `boreal-phoenix-405421`)
- `gcloud` CLI: https://cloud.google.com/sdk/docs/install
- Terraform ≥ 1.7: https://developer.hashicorp.com/terraform/install
- Node.js 20+
- Access to the GitHub repo: `kennethapple/agentwatch`

---

## Step 1 — Clone and configure

```bash
git clone https://github.com/kennethapple/agentwatch
cd agentwatch

cp infra/config.env infra/config.local.env
```

Edit `infra/config.local.env`:

```bash
GCP_PROJECT_ID="boreal-phoenix-405421"
GITHUB_REPO="kennethapple/agentwatch"
# GCP_REGION defaults to us-central1 — only change if needed
```

`config.local.env` is gitignored — it never gets committed.

---

## Step 2 — Bootstrap (first developer only, run once per project)

Creates the GCS Terraform state bucket and Workload Identity Federation.

```bash
gcloud auth login
chmod +x infra/bootstrap.sh
./infra/bootstrap.sh
```

The script is idempotent — safe to re-run. It will:
- Confirm with you before making any changes
- Warn you if your active gcloud project differs from config
- Print the 6 GitHub Actions secrets you need in Step 3

---

## Step 3 — GitHub Actions secrets (first developer only)

Go to **https://github.com/kennethapple/agentwatch/settings/secrets/actions**
and add the 6 secrets printed by bootstrap.sh:

| Secret | How to get it |
|---|---|
| `GCP_PROJECT_ID` | Printed by bootstrap.sh |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Printed by bootstrap.sh |
| `GCP_DEPLOY_SA` | Printed by bootstrap.sh |
| `ANTHROPIC_API_KEY` | console.anthropic.com |
| `SLACK_SIGNING_SECRET` | Slack app → Basic Information → Signing Secret |
| `GMAIL_WEBHOOK_TOKEN` | Printed by bootstrap.sh — also save for Step 4 |

---

## Step 4 — Terraform apply (first developer only)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — fill in the three sensitive values:

```hcl
anthropic_api_key    = "sk-ant-..."        # from console.anthropic.com
slack_signing_secret = "your-secret"       # from Slack app settings
gmail_webhook_token  = "paste-from-step-2" # printed by bootstrap.sh
```

```bash
terraform init    # downloads providers, connects to GCS backend
terraform plan    # review ~35 resources to be created
terraform apply   # takes ~5 minutes
```

Note the outputs — you'll need them for Steps 5 and 6:
```bash
terraform output
```

---

## Step 5 — Trigger first image deploy

Terraform deploys Cloud Run with a placeholder image. Push real images by
triggering the deploy workflow:

```bash
git commit --allow-empty -m "ci: trigger initial deploy"
git push origin main
```

Watch **Actions** tab — takes ~4 minutes. After it completes, open:
```bash
terraform output frontend_url
```

---

## Step 6 — Connect Gmail

```bash
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh
```

The Gmail watch expires every 7 days. Re-run this script weekly to renew,
or set up a Cloud Scheduler job (see Useful commands below).

---

## Step 7 — Connect Slack

```bash
./infra/scripts/setup-slack-app.sh
```

Paste the printed URL into your Slack app's **Event Subscriptions** page.
Subscribe to: `message.channels`, `message.groups`, `app_mention`.

---

## Joining an existing deployment

A second developer doesn't need to run bootstrap or touch Terraform.

```bash
git clone https://github.com/kennethapple/agentwatch
cd agentwatch

# Configure local environment
cp infra/config.env infra/config.local.env
# Edit: set GCP_PROJECT_ID=boreal-phoenix-405421 and GITHUB_REPO=kennethapple/agentwatch

# Authenticate to GCP
gcloud auth login
gcloud config set project boreal-phoenix-405421

# Run setup scripts (they read config.local.env automatically)
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh
./infra/scripts/setup-slack-app.sh
```

To make changes: open a PR. The CI workflow runs tests and posts a
Terraform plan as a PR comment. Merge to main to auto-deploy.

---

## CI/CD overview

| Trigger | Workflow | What runs |
|---|---|---|
| PR to `main` | `ci.yml` | Tests, lint, terraform validate |
| PR to `main` (infra changes) | `terraform.yml` | `terraform plan` posted as PR comment |
| Push to `main` (infra changes) | `terraform.yml` | `terraform apply` |
| Push to `main` (agent changes) | `deploy.yml` | Build image → Cloud Run |
| Push to `main` (frontend changes) | `deploy.yml` | Build image → Cloud Run |
| Push to `main` (ingest changes) | `deploy.yml` | Re-deploy Cloud Functions |

---

## Useful commands

```bash
# Tail agent logs
gcloud run services logs tail agentwatch-agent \
  --region us-central1 --project boreal-phoenix-405421

# Tail ingest function logs
gcloud functions logs read agentwatch-ingest-gmail \
  --region us-central1 --project boreal-phoenix-405421 --limit 50

# Manually simulate an event (no real webhook needed)
cd services/ingest
AGENT_URL=$(gcloud run services describe agentwatch-agent \
  --region us-central1 --project boreal-phoenix-405421 \
  --format='value(status.url)') \
node scripts/simulate.js --source gmail --fixture fixtures/email-approval.json

# Renew Gmail watch manually
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh

# Cloud Scheduler job to auto-renew Gmail watch weekly
gcloud scheduler jobs create http agentwatch-gmail-watch-renewal \
  --location us-central1 \
  --project boreal-phoenix-405421 \
  --schedule "0 9 * * MON" \
  --uri "$(gcloud functions describe agentwatch-ingest-gmail \
    --region us-central1 --project boreal-phoenix-405421 \
    --format='value(serviceConfig.uri)')/renew" \
  --message-body '{"renew": true}'
```

---

## Troubleshooting

**`config.local.env not found`**
Run `cp infra/config.env infra/config.local.env` and fill in the values.

**`terraform init` fails with bucket not found**
Run `./infra/bootstrap.sh` first — it creates the GCS bucket.

**GitHub Actions: `Error: google-github-actions/auth failed`**
- Verify `GCP_WORKLOAD_IDENTITY_PROVIDER` starts with `projects/` (full resource path)
- Verify `GCP_DEPLOY_SA` is the full email address
- Check the WIF attribute condition matches your fork's repo name

**Agent not receiving Pub/Sub events**
```bash
gcloud pubsub subscriptions describe agentwatch-agent-sub \
  --project boreal-phoenix-405421
# Check pushConfig.pushEndpoint matches the agent Cloud Run URL
```

**Cloud Functions returning 401**
The Gmail push token in Secret Manager must match what was registered
with `gmail.users.watch`. Re-run `setup-gmail-watch.sh` to re-sync.

**Terraform apply fails with WIF resources already existing**
Bootstrap created them outside Terraform state. Import them:
```bash
terraform import google_iam_workload_identity_pool.github \
  projects/boreal-phoenix-405421/locations/global/workloadIdentityPools/agentwatch-gh-pool

terraform import google_iam_workload_identity_pool_provider.github \
  projects/boreal-phoenix-405421/locations/global/workloadIdentityPools/agentwatch-gh-pool/providers/agentwatch-gh-provider
```
