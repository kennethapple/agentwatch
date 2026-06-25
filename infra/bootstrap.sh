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
#   - gcloud CLI authenticated as Owner of the project
#   - GITHUB_REPO set to "owner/repo" if different from default

set -euo pipefail

PROJECT_ID="boreal-phoenix-405421"
REGION="us-central1"
GITHUB_REPO="${GITHUB_REPO:-kennethapple/agentwatch}"
TFSTATE_BUCKET="${PROJECT_ID}-tfstate"
WIF_POOL="agentwatch-gh-pool"
WIF_PROVIDER="agentwatch-gh-provider"
DEPLOY_SA="agentwatch-deploy-sa"
DEPLOY_SA_EMAIL="${DEPLOY_SA}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "▶ AgentWatch bootstrap"
echo "  Project:        $PROJECT_ID"
echo "  GitHub repo:    $GITHUB_REPO"
echo "  tfstate bucket: gs://$TFSTATE_BUCKET"
echo ""

# ── Confirm before making IAM changes ────────────────────────────────────────
echo "This script will:"
echo "  - Enable 5 GCP APIs"
echo "  - Create GCS bucket gs://$TFSTATE_BUCKET"
echo "  - Create service account $DEPLOY_SA_EMAIL"
echo "  - Grant it scoped project IAM roles (no primitive roles)"
echo "  - Create Workload Identity Pool + Provider for $GITHUB_REPO"
echo ""
read -r -p "Continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

# ── 1. Enable APIs needed before Terraform can run ───────────────────────────
echo "▶ Enabling bootstrap APIs..."
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  storage.googleapis.com \
  --project="$PROJECT_ID"
echo "  Done."

# ── 2. Create GCS bucket for Terraform state ─────────────────────────────────
echo "▶ Creating tfstate bucket: gs://$TFSTATE_BUCKET"
if gsutil ls -p "$PROJECT_ID" "gs://$TFSTATE_BUCKET" &>/dev/null; then
  echo "  Bucket already exists, skipping."
else
  gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://$TFSTATE_BUCKET"
  gsutil versioning set on "gs://$TFSTATE_BUCKET"
  # Uniform bucket-level access — disables per-object ACLs
  gsutil ubla set on "gs://$TFSTATE_BUCKET"
  # Explicit public access prevention — belt and braces
  gsutil pap set enforced "gs://$TFSTATE_BUCKET"
  echo "  Created with versioning + public access prevention."
fi

# ── 3. Create deploy service account ─────────────────────────────────────────
echo "▶ Creating deploy service account: $DEPLOY_SA_EMAIL"
if gcloud iam service-accounts describe "$DEPLOY_SA_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
  echo "  Already exists, skipping."
else
  gcloud iam service-accounts create "$DEPLOY_SA" \
    --display-name="AgentWatch GitHub Deploy" \
    --project="$PROJECT_ID"
  echo "  Created."
fi

# Grant only the roles Terraform + CI/CD actually need.
# No primitive roles (roles/editor, roles/owner) — scoped predefined roles only.
echo "▶ Granting IAM roles to deploy SA..."
for ROLE in \
  roles/run.admin \
  roles/cloudfunctions.admin \
  roles/pubsub.admin \
  roles/datastore.owner \
  roles/secretmanager.admin \
  roles/artifactregistry.admin \
  roles/iam.serviceAccountAdmin \
  roles/iam.workloadIdentityPoolAdmin \
  roles/iam.serviceAccountUser \
  roles/storage.admin \
  roles/serviceusage.serviceUsageAdmin \
  roles/resourcemanager.projectIamAdmin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$DEPLOY_SA_EMAIL" \
    --role="$ROLE" \
    --condition=None \
    --quiet
done
echo "  Roles granted (no primitive roles)."

# ── 4. Workload Identity Federation ──────────────────────────────────────────
echo "▶ Creating Workload Identity Pool: $WIF_POOL"
if gcloud iam workload-identity-pools describe "$WIF_POOL" \
    --location=global --project="$PROJECT_ID" &>/dev/null; then
  echo "  Already exists, skipping."
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
  echo "  Already exists, skipping."
else
  gcloud iam workload-identity-pools providers create-oidc "$WIF_PROVIDER" \
    --workload-identity-pool="$WIF_POOL" \
    --location=global \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='${GITHUB_REPO}'" \
    --project="$PROJECT_ID"
  echo "  Created (scoped to repo: $GITHUB_REPO)."
fi

# Allow GitHub Actions for this specific repo to impersonate the deploy SA
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

gcloud iam service-accounts add-iam-policy-binding "$DEPLOY_SA_EMAIL" \
  --project="$PROJECT_ID" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/attribute.repository/${GITHUB_REPO}" \
  --role="roles/iam.workloadIdentityUser"

echo "  WIF binding created for repo: $GITHUB_REPO"

# ── 5. Output GitHub Actions secrets ─────────────────────────────────────────
WIF_PROVIDER_RESOURCE="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/providers/${WIF_PROVIDER}"

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Bootstrap complete."
echo "  Add these 6 secrets to GitHub Actions:"
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
echo "    (from console.anthropic.com)"
echo ""
echo "  SLACK_SIGNING_SECRET"
echo "    (from your Slack app → Basic Information → Signing Secret)"
echo ""
echo "  GMAIL_WEBHOOK_TOKEN"
echo "    (paste this random value — save it, you'll need it for terraform.tfvars too)"
echo "    $(openssl rand -hex 32)"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "▶ Next: cd infra/terraform && terraform init && terraform apply"
