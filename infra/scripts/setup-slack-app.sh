#!/usr/bin/env bash
# setup-slack-app.sh
# Prints the URLs you need to register in your Slack app settings.
# Run after terraform apply.

set -euo pipefail

PROJECT_ID="boreal-phoenix-405421"
REGION="us-central1"

SLACK_URL=$(gcloud functions describe agentwatch-ingest-slack \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(serviceConfig.uri)")

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Slack app configuration"
echo "  https://api.slack.com/apps → your app → Event Subscriptions"
echo ""
echo "  Request URL (paste this):"
echo "    $SLACK_URL"
echo ""
echo "  Subscribe to bot events:"
echo "    message.channels   — messages in public channels"
echo "    message.groups     — messages in private channels"
echo "    app_mention        — @mentions of your bot"
echo ""
echo "  After saving, Slack will POST a challenge to the URL."
echo "  The ingest function handles it automatically."
echo "══════════════════════════════════════════════════════════════"
