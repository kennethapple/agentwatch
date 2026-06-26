# Ingest service

HTTP-triggered Cloud Functions that receive webhooks from Gmail and Slack,
validate and normalize them into a common `AgentEvent` schema, then publish
to the `agentwatch-events` Pub/Sub topic.

**Runtime:** Node.js 20, CommonJS (not ESM — GCF v2 compatibility requirement)
**Deployed:** `agentwatch-ingest-gmail` + `agentwatch-ingest-slack` in `us-central1`

## Structure

```
src/
  index.js          ← registers handlers with @google-cloud/functions-framework
  sources/
    gmail.js        ← Gmail push notification handler
    slack.js        ← Slack Events API handler
  lib/
    normalize.js    ← AgentEvent schema constructor
    pubsub.js       ← Pub/Sub publish helper (lazy-initialized client)
    validate.js     ← HMAC + token validation
    firestore.js    ← Event audit log writer (lazy-initialized client)
fixtures/           ← Sample payloads for local testing
scripts/
  simulate.js       ← Post a fixture directly to the agent (local dev)
```

## Important implementation notes

**CommonJS only** — this service uses `require()`/`module.exports`, not ESM
(`import`/`export`). GCF v2 with Node 20 has issues with `"type": "module"`.
Do not add `"type": "module"` to `package.json`.

**Lazy GCP client initialization** — Firestore and Pub/Sub clients are
created inside the first function call, not at module load time. This prevents
the Cloud Run health check from failing during cold start before credentials
are available.

**functions-framework registration** — handlers must be registered via
`http()` from `@google-cloud/functions-framework` in `index.js`. Bare exports
are not discovered with the GCF v2 runtime.

## AgentEvent schema

```js
{
  id: string,          // UUID
  source: string,      // 'gmail' | 'slack'
  type: string,        // 'gmail.email_received' | 'slack.message'
  payload: object,     // normalized source-specific fields
  rawPayload: object,  // original webhook body
  receivedAt: string,  // ISO 8601
}
```

## Local development

```bash
npm install

# Simulate a Gmail event (posts directly to local agent on :8080)
npm run simulate -- --source gmail --fixture fixtures/email-approval.json

# Simulate a Slack event
npm run simulate -- --source slack --fixture fixtures/slack-message.json

# Override agent URL
AGENT_URL=https://agentwatch-agent-xxxx-uc.a.run.app \
  npm run simulate -- --source gmail --fixture fixtures/email-approval.json
```

## Adding a new source

See [docs/adding-event-sources.md](../../docs/adding-event-sources.md).

## Deployment

Deployed automatically by `.github/workflows/deploy.yml` on any push to `main`
that changes `services/ingest/**`.

Manual re-deploy:
```bash
gcloud functions deploy agentwatch-ingest-gmail \
  --gen2 --runtime nodejs20 \
  --entry-point gmailHandler \
  --source . \
  --trigger-http \
  --region us-central1 \
  --project boreal-phoenix-405421
```
