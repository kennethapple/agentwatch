#!/usr/bin/env bash
# setup-gmail-watch.sh
# Registers Gmail push notifications so new emails trigger the ingest function.
# Run once after terraform apply. Re-run weekly to renew the watch (7-day expiry).
#
# Usage:
#   GMAIL_ADDRESS=you@example.com ./infra/scripts/setup-gmail-watch.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.local.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: infra/config.local.env not found."
  echo "Run ./infra/bootstrap.sh first."
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
  echo "Error: GCP_PROJECT_ID not set in config.local.env"
  exit 1
fi

if [[ -z "${GMAIL_ADDRESS:-}" ]]; then
  echo "Error: set GMAIL_ADDRESS before running"
  echo "  GMAIL_ADDRESS=you@example.com ./infra/scripts/setup-gmail-watch.sh"
  exit 1
fi

APP_NAME="${APP_NAME:-agentwatch}"
GCP_REGION="${GCP_REGION:-us-central1}"

echo "▶ Setting up Gmail watch"
echo "  Project:       $GCP_PROJECT_ID"
echo "  Gmail address: $GMAIL_ADDRESS"
echo ""

# Get the Gmail webhook token from Secret Manager
echo "▶ Fetching webhook token from Secret Manager..."
GMAIL_TOKEN=$(gcloud secrets versions access latest \
  --secret="${APP_NAME}-gmail-webhook-token" \
  --project="$GCP_PROJECT_ID")

# Get the ingest function URL
echo "▶ Fetching ingest function URL..."
INGEST_URL=$(gcloud functions describe ${APP_NAME}-ingest-gmail \
  --region="$GCP_REGION" \
  --project="$GCP_PROJECT_ID" \
  --format="value(serviceConfig.uri)")

WEBHOOK_URL="${INGEST_URL}?token=${GMAIL_TOKEN}"
GMAIL_TOPIC="projects/${GCP_PROJECT_ID}/topics/${APP_NAME}-gmail-push"

echo "  Ingest URL: $INGEST_URL"
echo ""

# Create Gmail-specific Pub/Sub topic (separate from main events topic)
echo "▶ Creating Gmail Pub/Sub topic..."
gcloud pubsub topics create "${APP_NAME}-gmail-push" \
  --project="$GCP_PROJECT_ID" 2>/dev/null \
  && echo "  Created." \
  || echo "  Already exists, skipping."

# Grant Gmail's service account publish rights
echo "▶ Granting Gmail service account publish access..."
gcloud pubsub topics add-iam-policy-binding "${APP_NAME}-gmail-push" \
  --project="$GCP_PROJECT_ID" \
  --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" \
  --role="roles/pubsub.publisher" \
  --quiet

# Create or update push subscription → ingest function
echo "▶ Configuring Pub/Sub push subscription..."
if gcloud pubsub subscriptions describe "${APP_NAME}-gmail-push-sub" \
    --project="$GCP_PROJECT_ID" &>/dev/null; then
  gcloud pubsub subscriptions modify-push-config "${APP_NAME}-gmail-push-sub" \
    --push-endpoint="$WEBHOOK_URL" \
    --project="$GCP_PROJECT_ID"
  echo "  Updated existing subscription."
else
  gcloud pubsub subscriptions create "${APP_NAME}-gmail-push-sub" \
    --topic="${APP_NAME}-gmail-push" \
    --push-endpoint="$WEBHOOK_URL" \
    --project="$GCP_PROJECT_ID"
  echo "  Created subscription."
fi

# Register gmail.users.watch
echo "▶ Registering Gmail watch for $GMAIL_ADDRESS..."
ACCESS_TOKEN=$(gcloud auth print-access-token)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "https://gmail.googleapis.com/gmail/v1/users/${GMAIL_ADDRESS}/watch" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"topicName\": \"${GMAIL_TOPIC}\",
    \"labelIds\": [\"INBOX\"],
    \"labelFilterAction\": \"include\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -1)

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "  Error: Gmail API returned $HTTP_CODE"
  echo "  $BODY"
  echo ""
  echo "  Make sure your gcloud account has Gmail API access and the"
  echo "  gmail.googleapis.com API is enabled in project $GCP_PROJECT_ID."
  exit 1
fi

EXPIRY=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('expiration','unknown'))" 2>/dev/null || echo "unknown")
echo "  Registered. Expiry: $EXPIRY (epoch ms — ~7 days)"

echo ""
echo "✅ Gmail watch active for $GMAIL_ADDRESS"
echo ""
echo "   ⚠  The watch expires in ~7 days. Re-run this script to renew."
echo "   Tip: set up a Cloud Scheduler job to run this weekly:"
echo "   https://console.cloud.google.com/cloudscheduler?project=$GCP_PROJECT_ID"
echo ""

FRONTEND_URL=$(gcloud run services describe ${APP_NAME}-frontend \
  --region="$GCP_REGION" --project="$GCP_PROJECT_ID" \
  --format="value(status.url)" 2>/dev/null || echo "(deploy frontend first)")
echo "   Open the UI: $FRONTEND_URL"
