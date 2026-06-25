# Frontend

Next.js 14 App Router UI. Server components load initial run data from Firestore; a client component connects to the agent's SSE stream to show the live agent trace.

## Structure

```
src/
  app/
    layout.jsx        ← Shell: sidebar + main content area
    page.jsx          ← Home page (server component, loads recent runs)
    globals.css       ← All styles
  components/
    EventsClient.jsx  ← Client component: event list + SSE trace panel
  lib/
    firestore.js      ← Server-side Firestore helpers
```

## Pages

| Route | Description |
|---|---|
| `/` | Live events — event list + real-time agent trace |
| `/history` | (planned) Full run history with search |
| `/integrations/*` | (planned) Per-integration settings |

## SSE trace events

The `EventsClient` component subscribes to `GET /stream/:runId` on the agent service and renders each step type:

| Step type | Display |
|---|---|
| `classify` | Workflow name + event source/type |
| `reasoning` | Claude's thinking text |
| `tool_call` | Tool name + input JSON |
| `tool_result` | Tool output |
| `output` | Final agent output |
| `done` | Stream closes |
| `error` | Error message in red |

## Environment variables

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_AGENT_URL` | Agent Cloud Run service URL (public, used by browser for SSE) |
| `GCP_PROJECT_ID` | GCP project for server-side Firestore reads |

## Local development

```bash
npm install

# Point at local agent service
NEXT_PUBLIC_AGENT_URL=http://localhost:8080 \
GCP_PROJECT_ID=local-dev \
npm run dev
```

Open http://localhost:3000.

## Deployment

Built into a Docker image and deployed to Cloud Run via `.github/workflows/deploy.yml`.
The `next.config.mjs` sets `output: 'standalone'` for minimal image size.
