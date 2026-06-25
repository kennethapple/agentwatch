# Ingest service

HTTP-triggered Cloud Functions that receive webhooks from event sources, validate and normalize them into a common `AgentEvent` schema, then publish to the `agentwatch-events` Pub/Sub topic.

## Structure

```
src/
  index.js          ← exports all Cloud Function entry points
  sources/
    gmail.js        ← Gmail push notification handler
    slack.js        ← Slack Events API handler
  lib/
    normalize.js    ← AgentEvent schema constructor
    pubsub.js       ← Pub/Sub publish helper
    validate.js     ← HMAC + token validation
    firestore.js    ← Event audit log writer
fixtures/           ← Sample payloads for local testing
scripts/
  simulate.js       ← Post a fixture directly to the agent (local dev)
```

## AgentEvent schema

```ts
{
  id: string          // UUID
  source: string      // 'gmail' | 'slack' | 'calendar'
  type: string        // 'gmail.email_received' | 'slack.message' | ...
  payload: object     // normalized fields
  rawPayload: object  // original webhook body
  receivedAt: string  // ISO 8601
}
```

## Local development

```bash
npm install

# Simulate a Gmail event (posts directly to local agent on :8080)
npm run simulate -- --source gmail --fixture fixtures/email-approval.json

# Simulate a Slack event
npm run simulate -- --source slack --fixture fixtures/slack-message.json
```

## Adding a new source

See [docs/adding-event-sources.md](../../docs/adding-event-sources.md).

## Deployment

Deployed by Terraform via `infra/terraform/functions.tf`. The source directory is zipped and uploaded to GCS on each `terraform apply`.

For manual deployment:
```bash
gcloud functions deploy agentwatch-ingest-gmail \
  --gen2 --runtime nodejs20 \
  --entry-point gmailHandler \
  --trigger-http \
  --region us-central1 \
  --service-account agentwatch-ingest-sa@PROJECT.iam.gserviceaccount.com
```
