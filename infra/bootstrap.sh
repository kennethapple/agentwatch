#!/usr/bin/env bash
# bootstrap.sh — run once before terraform init
# Creates the GCS state bucket and Workload Identity Federation binding
# so GitHub Actions can authenticate to GCP without a service account key.
#
# Usage:
#   chmod +x infra/bootstrap.sh
#   ./infra/bootstrap.sh
#
# Prerequisites:
#   - gcloud CLI authenticated as an Owner/Editor of the project
#   - GITHUB_REPO set to "owner/repo" (e.g. "kennethapple/agentwatch")

set -euo pipefail

PROJECT_ID="boreal-phoenix-405421"
REGION="us-central1"
GITHUB_REPO="${GITHUB_REPO:-kennethapple/agentwatch}"
GITHUB_ORG="${GITHUB_REPO%%/*}"
TFSTATE_BUCKET="${PROJECT_ID}-tfstate"
WIF_POOL="agentwatch-gh-pool"
WIF_PROVIDER="agentwatch-gh-provider"
DEPLOY_SA="agentwatch-deploy-sa"

echo "▶ Bootstrapping AgentWatch on project: $PROJECT_ID"
echo "  GitHub repo:   $GITHUB_REPO"
echo "  tfstate bucket: gs://$TFSTATE_BUCKET"
echo ""

# ── 1. Enable APIs needed before Terraform can run ────────────────────────────
echo "▶ Enabling bootstrap APIs..."
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  storage.googleapis.com \
  --project="$PROJECT_ID"

# ── 2. Create GCS bucket for Terraform state ──────────────────────────────────
echo "▶ Creating tfstate bucket: gs://$TFSTATE_BUCKET"
if gsutil ls -p "$PROJECT_ID" "gs://$TFSTATE_BUCKET" &>/dev/null; then
  echo "  Bucket already exists, skipping."
else
  gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$TFSTATE_BUCKET"
  gsutil versioning set on "gs://$TFSTATE_BUCKET"
  gsutil ubla set on "gs://$TFSTATE_BUCKET"
  echo "  Created."
fi

# ── 3. Create deploy service account ──────────────────────────────────────────
DEPLOY_SA_EMAIL="${DEPLOY_SA}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "▶ Creating deploy service account: $DEPLOY_SA_EMAIL"
if gcloud iam service-accounts describe "$DEPLOY_SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  echo "  Service account already exists, skipping."
else
  gcloud iam service-accounts create "$DEPLOY_SA" \
    --display-name="AgentWatch GitHub Deploy" \
    --project="$PROJECT_ID"
  echo "  Created."
fi

# Grant deploy SA the roles Terraform + CI/CD need
echo "▶ Granting IAM roles to deploy SA..."
for ROLE in \
  roles/editor \
  roles/iam.serviceAccountAdmin \
  roles/iam.workloadIdentityPoolAdmin \
  roles/secretmanager.admin \
  roles/storage.admin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$DEPLOY_SA_EMAIL" \
    --role="$ROLE" \
    --condition=None \
    --quiet
done

# Allow deploy SA to impersonate itself (needed for WIF)
gcloud iam service-accounts add-iam-policy-binding "$DEPLOY_SA_EMAIL" \
  --project="$PROJECT_ID" \
  --member="serviceAccount:$DEPLOY_SA_EMAIL" \
  --role="roles/iam.serviceAccountTokenCreator"

echo "  Roles granted."

# ── 4. Workload Identity Federation ───────────────────────────────────────────
echo "▶ Creating Workload Identity Pool: $WIF_POOL"
if gcloud iam workload-identity-pools describe "$WIF_POOL" \
    --location=global --project="$PROJECT_ID" &>/dev/null; then
  echo "  Pool already exists, skipping."
else
  gcloud iam workload-identity-pools create "$WIF_POOL" \
    --location=global \
    --display-name="AgentWatch GitHub Actions" \
    --project="$PROJECT_ID"
  echo "  Created."
fi

echo "▶ Creating Workload Identity Provider: $WIF_PROVIDER"
if gcloud iam workload-identity-pools providers describe "$WIF_PROVIDER" \
    --workload-identity-pool="$WIF_POOL" \
    --location=global --project="$PROJECT_ID" &>/dev/null; then
  echo "  Provider already exists, skipping."
else
  gcloud iam workload-identity-pools providers create-oidc "$WIF_PROVIDER" \
    --workload-identity-pool="$WIF_POOL" \
    --location=global \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='${GITHUB_REPO}'" \
    --project="$PROJECT_ID"
  echo "  Created."
fi

# Allow the GitHub repo's Actions to impersonate the deploy SA
WIF_POOL_NUMBER=$(gcloud iam workload-identity-pools describe "$WIF_POOL" \
  --location=global --project="$PROJECT_ID" \
  --format="value(name)" | grep -o '[0-9]*$')

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

gcloud iam service-accounts add-iam-policy-binding "$DEPLOY_SA_EMAIL" \
  --project="$PROJECT_ID" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/attribute.repository/${GITHUB_REPO}" \
  --role="roles/iam.workloadIdentityUser"

# ── 5. Output GitHub Actions secrets ──────────────────────────────────────────
WIF_PROVIDER_RESOURCE="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/providers/${WIF_PROVIDER}"

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Bootstrap complete. Add these secrets to GitHub Actions:"
echo "  https://github.com/${GITHUB_REPO}/settings/secrets/actions"
echo ""
echo "  GCP_PROJECT_ID"
echo "    $PROJECT_ID"
echo ""
echo "  GCP_WORKLOAD_IDENTITY_PROVIDER"
echo "    $WIF_PROVIDER_RESOURCE"
echo ""
echo "  GCP_DEPLOY_SA"
echo "    $DEPLOY_SA_EMAIL"
echo ""
echo "  ANTHROPIC_API_KEY"
echo "    (your Anthropic API key — get from console.anthropic.com)"
echo ""
echo "  SLACK_SIGNING_SECRET"
echo "    (from your Slack app settings)"
echo ""
echo "  GMAIL_WEBHOOK_TOKEN"
echo "    (any random string — used to verify Gmail push notifications)"
echo "    $(openssl rand -hex 16)"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "▶ Next step: cd infra/terraform && terraform init && terraform apply"
