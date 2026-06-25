#!/usr/bin/env bash
# bootstrap.sh — run once per GCP project before terraform init
#
# Creates:
#   - GCS bucket for Terraform remote state
#   - Deploy service account for GitHub Actions
#   - Workload Identity Federation (keyless CI/CD auth — no SA keys)
#
# Usage:
#   cp infra/config.env infra/config.local.env
#   # edit infra/config.local.env with your GCP_PROJECT_ID and GITHUB_REPO
#   chmod +x infra/bootstrap.sh
#   ./infra/bootstrap.sh
#
# Run from the repo root. Safe to re-run — all steps are idempotent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load config ───────────────────────────────────────────────────────────────
CONFIG_FILE="$SCRIPT_DIR/config.local.env"
CONFIG_TEMPLATE="$SCRIPT_DIR/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: $CONFIG_FILE not found."
  echo ""
  echo "  cp infra/config.env infra/config.local.env"
  echo "  # edit infra/config.local.env with your GCP_PROJECT_ID and GITHUB_REPO"
  echo "  ./infra/bootstrap.sh"
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# ── Validate required config ──────────────────────────────────────────────────
ERRORS=0
if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  echo "Error: GCP_PROJECT_ID is not set in config.local.env"
  ERRORS=$((ERRORS + 1))
fi
if [[ -z "${GITHUB_REPO:-}" ]]; then
  echo "Error: GITHUB_REPO is not set in config.local.env (format: owner/repo)"
  ERRORS=$((ERRORS + 1))
fi
if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "Edit infra/config.local.env and try again."
  exit 1
fi

# Validate GITHUB_REPO format
if [[ ! "$GITHUB_REPO" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
  echo "Error: GITHUB_REPO must be in owner/repo format (e.g. kennethapple/agentwatch)"
  exit 1
fi

# ── Derived values (not user-configurable) ────────────────────────────────────
APP_NAME="${APP_NAME:-agentwatch}"
GCP_REGION="${GCP_REGION:-us-central1}"
TFSTATE_BUCKET="${GCP_PROJECT_ID}-${APP_NAME}-tfstate"
WIF_POOL="${APP_NAME}-gh-pool"
WIF_PROVIDER="${APP_NAME}-gh-provider"
DEPLOY_SA="${APP_NAME}-deploy-sa"
DEPLOY_SA_EMAIL="${DEPLOY_SA}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# ── Confirm before making changes ─────────────────────────────────────────────
echo "▶ AgentWatch bootstrap"
echo ""
echo "  Project:        $GCP_PROJECT_ID"
echo "  Region:         $GCP_REGION"
echo "  GitHub repo:    $GITHUB_REPO"
echo "  tfstate bucket: gs://$TFSTATE_BUCKET"
echo "  Deploy SA:      $DEPLOY_SA_EMAIL"
echo "  WIF pool:       $WIF_POOL"
echo ""
echo "This will:"
echo "  1. Enable 5 GCP APIs"
echo "  2. Create GCS bucket gs://$TFSTATE_BUCKET (versioned, no public access)"
echo "  3. Create service account $DEPLOY_SA_EMAIL"
echo "  4. Grant it scoped project IAM roles (no primitive roles)"
echo "  5. Create Workload Identity Pool + Provider scoped to $GITHUB_REPO"
echo ""

# Warn if the gcloud active project differs from config
ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
if [[ -n "$ACTIVE_PROJECT" && "$ACTIVE_PROJECT" != "$GCP_PROJECT_ID" ]]; then
  echo "⚠  Warning: your active gcloud project is '$ACTIVE_PROJECT'"
  echo "   but config.local.env sets GCP_PROJECT_ID='$GCP_PROJECT_ID'"
  echo "   All commands will use --project=$GCP_PROJECT_ID explicitly."
  echo ""
fi

read -r -p "Continue? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

# ── 1. Enable APIs ────────────────────────────────────────────────────────────
echo "▶ Enabling bootstrap APIs..."
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  storage.googleapis.com \
  --project="$GCP_PROJECT_ID"
echo "  Done."

# ── 2. GCS state bucket ───────────────────────────────────────────────────────
echo "▶ Creating tfstate bucket: gs://$TFSTATE_BUCKET"
if gsutil ls -p "$GCP_PROJECT_ID" "gs://$TFSTATE_BUCKET" &>/dev/null; then
  echo "  Already exists, skipping."
else
  gsutil mb -p "$GCP_PROJECT_ID" -l "$GCP_REGION" "gs://$TFSTATE_BUCKET"
  gsutil versioning set on "gs://$TFSTATE_BUCKET"
  gsutil ubla set on "gs://$TFSTATE_BUCKET"
  gsutil pap set enforced "gs://$TFSTATE_BUCKET"
  echo "  Created with versioning + public access prevention."
fi

# ── 3. Deploy service account ─────────────────────────────────────────────────
echo "▶ Creating deploy service account: $DEPLOY_SA_EMAIL"
if gcloud iam service-accounts describe "$DEPLOY_SA_EMAIL" \
    --project="$GCP_PROJECT_ID" &>/dev/null; then
  echo "  Already exists, skipping."
else
  gcloud iam service-accounts create "$DEPLOY_SA" \
    --display-name="AgentWatch GitHub Deploy" \
    --project="$GCP_PROJECT_ID"
  echo "  Created."
fi

# Scoped predefined roles only — no primitive roles (editor/owner)
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
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:$DEPLOY_SA_EMAIL" \
    --role="$ROLE" \
    --condition=None \
    --quiet
done
echo "  Roles granted."

# ── 4. Workload Identity Federation ──────────────────────────────────────────
echo "▶ Creating Workload Identity Pool: $WIF_POOL"
if gcloud iam workload-identity-pools describe "$WIF_POOL" \
    --location=global --project="$GCP_PROJECT_ID" &>/dev/null; then
  echo "  Already exists, skipping."
else
  gcloud iam workload-identity-pools create "$WIF_POOL" \
    --location=global \
    --display-name="AgentWatch GitHub Actions" \
    --project="$GCP_PROJECT_ID"
  echo "  Created."
fi

echo "▶ Creating Workload Identity Provider: $WIF_PROVIDER"
if gcloud iam workload-identity-pools providers describe "$WIF_PROVIDER" \
    --workload-identity-pool="$WIF_POOL" \
    --location=global --project="$GCP_PROJECT_ID" &>/dev/null; then
  echo "  Already exists, skipping."
else
  gcloud iam workload-identity-pools providers create-oidc "$WIF_PROVIDER" \
    --workload-identity-pool="$WIF_POOL" \
    --location=global \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --attribute-condition="assertion.repository=='${GITHUB_REPO}'" \
    --project="$GCP_PROJECT_ID"
  echo "  Created (scoped to: $GITHUB_REPO)."
fi

# Bind: GitHub Actions for this repo → deploy SA
PROJECT_NUMBER=$(gcloud projects describe "$GCP_PROJECT_ID" \
  --format="value(projectNumber)")

gcloud iam service-accounts add-iam-policy-binding "$DEPLOY_SA_EMAIL" \
  --project="$GCP_PROJECT_ID" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/attribute.repository/${GITHUB_REPO}" \
  --role="roles/iam.workloadIdentityUser"

echo "  WIF binding created."

# ── 5. Update terraform backend bucket name ───────────────────────────────────
BACKEND_FILE="$SCRIPT_DIR/terraform/main.tf"
if grep -q "boreal-phoenix-405421-agentwatch-tfstate\|YOUR_PROJECT\|$TFSTATE_BUCKET" "$BACKEND_FILE"; then
  echo "▶ Terraform backend already configured, skipping."
else
  echo "▶ Updating Terraform backend bucket in main.tf..."
  sed -i.bak \
    "s|bucket = \".*-tfstate\"|bucket = \"$TFSTATE_BUCKET\"|" \
    "$BACKEND_FILE"
  rm -f "${BACKEND_FILE}.bak"
  echo "  Updated: bucket = \"$TFSTATE_BUCKET\""
fi

# ── 6. Print GitHub Actions secrets ──────────────────────────────────────────
WIF_PROVIDER_RESOURCE="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL}/providers/${WIF_PROVIDER}"

GMAIL_TOKEN=$(openssl rand -hex 32)

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Bootstrap complete. Add these 6 secrets to GitHub Actions:"
echo "  https://github.com/${GITHUB_REPO}/settings/secrets/actions"
echo ""
echo "  GCP_PROJECT_ID"
echo "    $GCP_PROJECT_ID"
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
echo "  GMAIL_WEBHOOK_TOKEN  ← also copy this into terraform.tfvars"
echo "    $GMAIL_TOKEN"
echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "▶ Next steps:"
echo "  1. Add the 6 secrets above to GitHub Actions"
echo "  2. cd infra/terraform"
echo "  3. cp terraform.tfvars.example terraform.tfvars"
echo "  4. Fill in terraform.tfvars (anthropic_api_key, slack_signing_secret,"
echo "     and the GMAIL_WEBHOOK_TOKEN printed above)"
echo "  5. terraform init && terraform apply"
