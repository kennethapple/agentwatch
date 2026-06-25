#!/usr/bin/env bash
# setup-slack-app.sh
# Prints the Slack Events API URL to register in your Slack app settings.
# Run after terraform apply.

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

APP_NAME="${APP_NAME:-agentwatch}"
GCP_REGION="${GCP_REGION:-us-central1}"

echo "▶ Fetching Slack ingest function URL..."
SLACK_URL=$(gcloud functions describe ${APP_NAME}-ingest-slack \
  --region="$GCP_REGION" \
  --project="$GCP_PROJECT_ID" \
  --format="value(serviceConfig.uri)")

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo "  Slack app configuration"
echo ""
echo "  1. Go to: https://api.slack.com/apps → your app"
echo "  2. Click 'Event Subscriptions' in the left sidebar"
echo "  3. Toggle 'Enable Events' ON"
echo "  4. Paste this as the Request URL:"
echo ""
echo "     $SLACK_URL"
echo ""
echo "  5. Wait for Slack to verify it (the function handles the challenge)"
echo "  6. Under 'Subscribe to bot events', add:"
echo "       message.channels   — messages in public channels"
echo "       message.groups     — messages in private channels"
echo "       app_mention        — @mentions of your bot"
echo "  7. Click Save Changes"
echo "  8. Reinstall the app to your workspace if prompted"
echo "══════════════════════════════════════════════════════════════════"
