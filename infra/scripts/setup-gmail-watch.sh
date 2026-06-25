#!/usr/bin/env bash
# setup-gmail-watch.sh
# Registers a Gmail push notification so new emails trigger our ingest function.
# Run this once after `terraform apply` completes.
#
# Usage:
#   GMAIL_ADDRESS=you@example.com ./infra/scripts/setup-gmail-watch.sh

set -euo pipefail

PROJECT_ID="boreal-phoenix-405421"
REGION="us-central1"
GMAIL_ADDRESS="${GMAIL_ADDRESS:-}"

if [[ -z "$GMAIL_ADDRESS" ]]; then
  echo "Error: set GMAIL_ADDRESS=you@example.com before running"
  exit 1
fi

# Get the Gmail webhook token from Secret Manager
GMAIL_TOKEN=$(gcloud secrets versions access latest \
  --secret="gmail-webhook-token" \
  --project="$PROJECT_ID")

# Get the ingest function URL from Cloud Functions
INGEST_URL=$(gcloud functions describe agentwatch-ingest-gmail \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(serviceConfig.uri)")

WEBHOOK_URL="${INGEST_URL}?token=${GMAIL_TOKEN}"

echo "▶ Gmail address:  $GMAIL_ADDRESS"
echo "▶ Webhook URL:    $WEBHOOK_URL"
echo ""

# Create a Pub/Sub topic for Gmail to push to (separate from our events topic)
GMAIL_TOPIC="projects/${PROJECT_ID}/topics/agentwatch-gmail-push"

echo "▶ Creating Gmail Pub/Sub topic..."
gcloud pubsub topics create agentwatch-gmail-push \
  --project="$PROJECT_ID" 2>/dev/null || echo "  (already exists)"

# Grant Gmail service account publish rights on the topic
echo "▶ Granting Gmail service account publish access..."
gcloud pubsub topics add-iam-policy-binding agentwatch-gmail-push \
  --project="$PROJECT_ID" \
  --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

# Create a push subscription pointing at our ingest function
echo "▶ Creating Pub/Sub push subscription → ingest function..."
gcloud pubsub subscriptions create agentwatch-gmail-push-sub \
  --topic=agentwatch-gmail-push \
  --push-endpoint="$WEBHOOK_URL" \
  --project="$PROJECT_ID" 2>/dev/null || \
gcloud pubsub subscriptions modify-push-config agentwatch-gmail-push-sub \
  --push-endpoint="$WEBHOOK_URL" \
  --project="$PROJECT_ID"

# Call gmail.users.watch via gcloud (requires Gmail API enabled and OAuth scope)
echo "▶ Registering Gmail watch for $GMAIL_ADDRESS..."
ACCESS_TOKEN=$(gcloud auth print-access-token)

curl -s -X POST \
  "https://gmail.googleapis.com/gmail/v1/users/${GMAIL_ADDRESS}/watch" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"topicName\": \"${GMAIL_TOPIC}\",
    \"labelIds\": [\"INBOX\"],
    \"labelFilterAction\": \"include\"
  }" | python3 -m json.tool

echo ""
echo "✅ Gmail watch registered."
echo "   Expiry: ~7 days. Re-run this script weekly, or set up a Cloud Scheduler job."
echo ""
echo "▶ To verify: send an email to $GMAIL_ADDRESS and watch the agent run at:"
FRONTEND_URL=$(gcloud run services describe agentwatch-frontend \
  --region="$REGION" --project="$PROJECT_ID" \
  --format="value(status.url)" 2>/dev/null || echo "(deploy frontend first)")
echo "   $FRONTEND_URL"
