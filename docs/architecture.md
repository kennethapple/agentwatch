# Architecture

## Overview

AgentWatch is an event-driven agent platform. External services (Gmail, Slack, Calendar) emit events that trigger a Claude-powered agent. The agent reasons, calls MCP tools, and streams every step to a browser UI in real time.

```
┌─────────────┐    ┌──────────────────┐    ┌─────────┐    ┌─────────────────────┐    ┌──────────┐
│ Gmail/Slack │───▶│ Cloud Functions  │───▶│ Pub/Sub │───▶│ Cloud Run (agent)   │───▶│ Next.js  │
│ Calendar    │    │ (normalize+emit) │    │ (queue) │    │ Claude + MCP tools  │    │ (SSE)    │
└─────────────┘    └──────────────────┘    └─────────┘    └─────────────────────┘    └──────────┘
                                                                     │
                                                                     ▼
                                                              ┌──────────────┐
                                                              │  Firestore   │
                                                              │ (event log + │
                                                              │  run steps)  │
                                                              └──────────────┘
```

## Component decisions

### Cloud Functions (ingest)

Each event source posts to an HTTP-triggered Cloud Function (2nd gen). The function:
1. Validates the request (HMAC signature for Slack, JWT for Google)
2. Normalizes the payload into a common `AgentEvent` schema
3. Publishes a message to the `agentwatch-events` Pub/Sub topic
4. Writes the raw event to Firestore for audit

We use one function per source (rather than a single fan-in) so each can be deployed, scaled, and rolled back independently.

### Pub/Sub

The `agentwatch-events` topic decouples ingestion from the agent. The agent Cloud Run service subscribes via a **push subscription** — GCP delivers each message as an HTTP POST, so we don't need a polling loop.

Retry policy: exponential backoff, max 5 retries, dead-letter topic `agentwatch-events-dlq`.

### Cloud Run (agent)

Stateless container, scales to zero. Two responsibilities:

1. **POST /run** — receives Pub/Sub push messages, starts an agent run
2. **GET /stream/:runId** — Server-Sent Events endpoint the frontend subscribes to

The agent uses the Anthropic SDK with `stream: true`. Each streamed token/tool-call is:
- Written to Firestore (`runs/{runId}/steps/{stepId}`)
- Flushed to any connected SSE clients

MCP connectors are loaded at startup from the `MCP_SERVERS` environment variable (JSON array of `{name, url}` objects).

### Firestore

Document structure:

```
events/
  {eventId}/          ← normalized AgentEvent, written by Cloud Functions
    source: 'gmail'
    type: 'email.received'
    payload: {...}
    createdAt: Timestamp

runs/
  {runId}/            ← one per agent invocation
    eventId: string
    status: 'running' | 'done' | 'failed'
    createdAt: Timestamp
    steps/
      {stepId}/       ← one per streamed agent step
        type: 'reasoning' | 'tool_call' | 'tool_result' | 'output'
        content: string | object
        createdAt: Timestamp
```

### Frontend (Next.js on Cloud Run)

- App Router, React Server Components for the shell
- Client component subscribes to `GET /stream/:runId` via `EventSource`
- Firebase Auth for user sessions (Google OAuth)
- No Supabase dependency — all state from Firestore + SSE

### Secret Manager

All credentials are stored in Secret Manager and mounted as environment variables at Cloud Run deploy time:

| Secret name | Used by |
|---|---|
| `anthropic-api-key` | Agent service |
| `slack-signing-secret` | Ingest function |
| `gmail-webhook-token` | Ingest function |
| `firebase-service-account` | Agent + frontend |

## Data flow walkthrough

1. Gmail receives an email. Google's Pub/Sub push (set up via `gmail.users.watch`) POSTs to the `agentwatch-ingest-gmail` Cloud Function.
2. The function validates the push token, decodes the base64 Gmail notification, fetches the full thread via Gmail API, normalizes it to `AgentEvent`, and publishes to `agentwatch-events`.
3. Pub/Sub delivers the message to the agent Cloud Run service via push subscription.
4. The agent service creates a Firestore run document, then opens a Claude streaming API call.
5. As Claude streams tokens and tool calls, each step is written to Firestore and flushed to any SSE clients watching that `runId`.
6. The frontend UI (already subscribed to that `runId`'s SSE stream) renders each step in real time.
