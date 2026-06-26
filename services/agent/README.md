# Agent service

Cloud Run service that receives `AgentEvent` messages from Pub/Sub, runs them
through a Claude-powered agent, and streams every reasoning step and tool call
to connected clients via Server-Sent Events.

**Deployed:** `agentwatch-agent` in `us-central1`
**Runtime:** Node.js 20, ESM (`"type": "module"`)
**Model:** `claude-sonnet-4-6` (streaming)

## Structure

```
src/
  server.js           ← Express entry point (:8080)
  routes/
    run.js            ← POST /run  — Pub/Sub push receiver
    stream.js         ← GET  /stream/:runId  — SSE stream
    health.js         ← GET  /health  — Cloud Run liveness probe
  lib/
    agent.js          ← Claude streaming runner + MCP tool dispatch
    sse.js            ← In-process SSE fan-out (supports multiple clients)
    firestore.js      ← Run + step persistence
    pubsub.js         ← Pub/Sub push message decoder
  workflows/
    index.js          ← Event type → system prompt + tool list registry
```

## API

### `POST /run`

Receives a Pub/Sub push envelope. Responds `200` immediately (within
Pub/Sub's 10s deadline), then runs the agent asynchronously.

```json
// Request body (Pub/Sub push format)
{
  "message": {
    "data": "<base64-encoded AgentEvent JSON>",
    "attributes": { "source": "gmail", "type": "gmail.email_received" }
  }
}
```

### `GET /stream/:runId`

Server-Sent Events stream. Each `data:` line is a JSON-encoded step.
If the run is already complete, replays stored steps and closes immediately.

| `type` | Fields | Description |
|---|---|---|
| `classify` | `workflow`, `event` | Workflow matched for this event |
| `reasoning` | `content` | Claude thinking text |
| `tool_call` | `tool`, `input` | MCP tool invocation |
| `tool_result` | `tool`, `content` | MCP tool response |
| `output` | `content` | Final agent output |
| `done` | `runId` | Run complete — stream closes |
| `error` | `content` | Run failed |

### `GET /health`

Returns `{ status: "ok", ts: "<ISO timestamp>" }`. Used by Cloud Run liveness probe.

## Workflows

Workflows are defined in `src/workflows/index.js`. Each workflow matches
an event type and provides a system prompt + list of MCP tool names.

| Workflow | Matches | Tools |
|---|---|---|
| `gmail-email` | `gmail.email_received` | gmail, crm, calendar |
| `slack-message` | `slack.message` | slack |
| `calendar-upcoming` | `calendar.*` | calendar, gmail, slack |
| `generic` | anything else | none |

To add a workflow, add an entry to the `workflows` array in `src/workflows/index.js`.

## MCP configuration

Set `MCP_SERVERS` as a JSON array of `{ name, url }` objects on the Cloud Run service:

```bash
gcloud run services update agentwatch-agent \
  --region us-central1 \
  --project boreal-phoenix-405421 \
  --set-env-vars 'MCP_SERVERS=[{"name":"gmail","url":"https://..."},{"name":"slack","url":"https://..."}]'
```

If `MCP_SERVERS` is not set, the agent runs without tools (reasoning only).

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Yes | Mounted from Secret Manager at runtime |
| `GCP_PROJECT_ID` | Yes | Set by Terraform |
| `PUBSUB_TOPIC` | Yes | Set by Terraform |
| `MCP_SERVERS` | No | JSON array of MCP server configs |
| `PORT` | No | HTTP port (default 8080) |

## Local development

```bash
npm install

# Minimal (no MCP, no Firestore)
ANTHROPIC_API_KEY=sk-ant-... GCP_PROJECT_ID=local-dev npm run dev

# With Firestore emulator
firebase emulators:start --only firestore &
FIRESTORE_EMULATOR_HOST=localhost:8080 \
ANTHROPIC_API_KEY=sk-ant-... \
GCP_PROJECT_ID=local-dev \
npm run dev

# Send a test event
cd ../ingest
node scripts/simulate.js --source gmail --fixture fixtures/email-approval.json
```

## Deployment

Deployed automatically by `.github/workflows/deploy.yml` on any push to `main`
that changes `services/agent/**`. Builds a Docker image, pushes to Artifact
Registry, and deploys to Cloud Run.

Manual re-deploy:
```bash
gcloud run deploy agentwatch-agent \
  --source . \
  --region us-central1 \
  --project boreal-phoenix-405421
```
