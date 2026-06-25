# Agent service

Cloud Run service that receives `AgentEvent` messages from Pub/Sub, runs them through a Claude-powered agent, and streams every step to connected clients via Server-Sent Events.

## Structure

```
src/
  server.js           ← Express entry point
  routes/
    run.js            ← POST /run  (Pub/Sub push receiver)
    stream.js         ← GET  /stream/:runId  (SSE)
    health.js         ← GET  /health
  lib/
    agent.js          ← Claude streaming runner
    sse.js            ← SSE fan-out manager
    firestore.js      ← Run + step persistence
    pubsub.js         ← Pub/Sub message decoder
  workflows/
    index.js          ← Event → system prompt + tool list registry
```

## API

### `POST /run`

Receives a Pub/Sub push envelope. Responds `200` immediately, then runs the agent asynchronously.

**Request body** (Pub/Sub push format):
```json
{
  "message": {
    "data": "<base64-encoded AgentEvent JSON>",
    "attributes": { "source": "gmail", "type": "gmail.email_received" }
  }
}
```

**Response:**
```json
{ "runId": "<uuid>" }
```

### `GET /stream/:runId`

SSE stream. Each event is a JSON-encoded step:

| `type` | Payload | Description |
|---|---|---|
| `classify` | `{ workflow, event }` | Workflow selected for this event |
| `reasoning` | `{ content }` | Claude thinking text |
| `tool_call` | `{ tool, input }` | MCP tool being called |
| `tool_result` | `{ tool, content }` | MCP tool result |
| `output` | `{ content }` | Final agent output |
| `done` | `{ runId }` | Run complete — stream closes |
| `error` | `{ content }` | Run failed |

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yes | Claude API key |
| `GCP_PROJECT_ID` | Yes | GCP project for Firestore |
| `MCP_SERVERS` | No | JSON array of `{ name, url }` MCP server configs |
| `PORT` | No | HTTP port (default 8080) |

## MCP server configuration

Set `MCP_SERVERS` as a JSON array:

```json
[
  { "name": "gmail", "url": "https://mcp.gmail.example.com/sse" },
  { "name": "slack", "url": "https://mcp.slack.example.com/sse" }
]
```

In Cloud Run this is set as an environment variable in Terraform (`cloudrun.tf`).

## Local development

```bash
npm install

# Minimal — runs without MCP tools
ANTHROPIC_API_KEY=sk-ant-... GCP_PROJECT_ID=local-dev npm run dev

# Full — with Firestore emulator
FIRESTORE_EMULATOR_HOST=localhost:8080 \
ANTHROPIC_API_KEY=sk-ant-... \
GCP_PROJECT_ID=local-dev \
npm run dev

# Test with a simulated event from the ingest service
cd ../ingest && node scripts/simulate.js --source gmail --fixture fixtures/email-approval.json
```

## Deployment

Built and deployed by `.github/workflows/deploy.yml` on push to `main`.

Manual:
```bash
gcloud run deploy agentwatch-agent --source . --region us-central1
```
