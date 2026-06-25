# Deployment guide

End-to-end steps to go from zero to a live AgentWatch on GCP.

## Prerequisites

- GCP project: `boreal-phoenix-405421`
- `gcloud` CLI authenticated as Owner
- Terraform ≥ 1.7
- GitHub repo: `kennethapple/agentwatch`
- Anthropic API key
- Slack app (or create one at api.slack.com/apps)
- Gmail account to monitor

---

## Step 1 — Bootstrap (run once)

Creates the GCS Terraform state bucket and Workload Identity Federation
so GitHub Actions can deploy without service account keys.

```bash
cd infra
chmod +x bootstrap.sh
./bootstrap.sh
```

The script prints five values at the end. **Copy them now** — you'll need them in Step 3.

---

## Step 2 — Terraform apply (first deploy)

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars — fill in the three sensitive values:
#   anthropic_api_key
#   slack_signing_secret
#   gmail_webhook_token  (any random 32-char hex string)

terraform init    # downloads providers, connects to GCS backend
terraform plan    # review what will be created (~35 resources)
terraform apply   # takes ~5 minutes on first run
```

After apply, note the outputs:

```bash
terraform output
# agent_url         → https://agentwatch-agent-xxxx-uc.a.run.app
# frontend_url      → https://agentwatch-frontend-xxxx-uc.a.run.app
# ingest_gmail_url  → https://us-central1-boreal-phoenix-405421.cloudfunctions.net/...
# ingest_slack_url  → https://us-central1-boreal-phoenix-405421.cloudfunctions.net/...
# wif_provider      → projects/123.../providers/agentwatch-gh-provider
# deploy_sa         → agentwatch-deploy-sa@boreal-phoenix-405421.iam.gserviceaccount.com
```

---

## Step 3 — GitHub Actions secrets

Go to **https://github.com/kennethapple/agentwatch/settings/secrets/actions**
and add these secrets:

| Secret name | Value |
|---|---|
| `GCP_PROJECT_ID` | `boreal-phoenix-405421` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | from `terraform output wif_provider` |
| `GCP_DEPLOY_SA` | from `terraform output deploy_sa` |
| `ANTHROPIC_API_KEY` | your Anthropic API key |
| `SLACK_SIGNING_SECRET` | your Slack app signing secret |
| `GMAIL_WEBHOOK_TOKEN` | the random token you set in terraform.tfvars |

---

## Step 4 — Initial container images

The first `terraform apply` deploys Cloud Run with a placeholder image.
Push real images by triggering the deploy workflow:

```bash
# Make a small change and push to trigger deploy workflow
git commit --allow-empty -m "ci: trigger initial deploy"
git push origin main
```

Watch the Actions tab — deploy takes ~4 minutes.

After it completes, open `terraform output frontend_url` in your browser.

---

## Step 5 — Connect Gmail

```bash
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh
```

This registers a Gmail push notification. New emails will now trigger
the agent automatically. The watch expires after 7 days — renew with
the same script, or automate it with Cloud Scheduler.

---

## Step 6 — Connect Slack

```bash
./infra/scripts/setup-slack-app.sh
```

Paste the printed URL into your Slack app's **Event Subscriptions** page.
Slack will send a verification challenge — the ingest function handles it automatically.

Subscribe to: `message.channels`, `message.groups`, `app_mention`.

---

## Ongoing deployments

After initial setup, all deployments are automatic via GitHub Actions:

| What changed | Workflow triggered | What happens |
|---|---|---|
| `services/agent/**` | `deploy.yml` | Builds + pushes Docker image, deploys to Cloud Run |
| `services/frontend/**` | `deploy.yml` | Builds + pushes Docker image, deploys to Cloud Run |
| `services/ingest/**` | `deploy.yml` + `terraform.yml` | Deploys Cloud Functions, re-zips source |
| `infra/terraform/**` | `terraform.yml` | `terraform apply` on merge, `plan` on PR |
| PR to `main` | `ci.yml` + `terraform.yml` | Tests + terraform plan posted as PR comment |

---

## Useful commands

```bash
# Tail agent logs
gcloud run services logs tail agentwatch-agent --region us-central1 --project boreal-phoenix-405421

# Tail ingest logs
gcloud functions logs read agentwatch-ingest-gmail --region us-central1 --project boreal-phoenix-405421 --limit 50

# View recent Firestore runs
gcloud firestore databases list --project boreal-phoenix-405421

# Manually simulate an event (bypasses Pub/Sub)
cd services/ingest
AGENT_URL=https://agentwatch-agent-xxxx-uc.a.run.app \
node scripts/simulate.js --source gmail --fixture fixtures/email-approval.json

# Renew Gmail watch (run weekly or set up Cloud Scheduler)
GMAIL_ADDRESS=you@yourcompany.com ./infra/scripts/setup-gmail-watch.sh
```

---

## Troubleshooting

**Agent not receiving events**
- Check Pub/Sub subscription: `gcloud pubsub subscriptions describe agentwatch-agent-sub --project boreal-phoenix-405421`
- Verify the push endpoint URL matches the agent Cloud Run URL
- Check dead-letter topic for failed deliveries: `gcloud pubsub subscriptions pull agentwatch-events-dlq-sub --auto-ack`

**Cloud Functions returning 401**
- Verify the Gmail push token in Secret Manager matches what you set in `gmail.users.watch`
- For Slack: check the signing secret matches your Slack app settings

**Terraform apply fails on WIF**
- Run `bootstrap.sh` first — it creates resources Terraform then imports into state
- If WIF pool already exists: `terraform import google_iam_workload_identity_pool.github projects/boreal-phoenix-405421/locations/global/workloadIdentityPools/agentwatch-gh-pool`

**GitHub Actions auth fails**
- Verify `GCP_WORKLOAD_IDENTITY_PROVIDER` secret is the full resource path (starts with `projects/`)
- Verify `GCP_DEPLOY_SA` is the full email (`agentwatch-deploy-sa@boreal-phoenix-405421.iam.gserviceaccount.com`)
