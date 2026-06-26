# Frontend

Next.js 14 App Router UI. Server components load initial run data from
Firestore; a client component connects to the agent's SSE stream for
real-time agent trace display.

**Deployed:** `agentwatch-frontend` in `us-central1`
**Runtime:** Node.js 20, React 18, Next.js 14.2

## Structure

```
src/
  app/
    layout.jsx        ← Shell: sidebar + main content wrapper
    page.jsx          ← Home (server component — loads recent runs from Firestore)
    globals.css       ← Full design system (CSS custom properties)
  components/
    EventsClient.jsx  ← Client component: event list + SSE trace panel
  lib/
    firestore.js      ← Server-side Firestore read helpers
public/
  .gitkeep            ← Keeps public/ present for Docker COPY
```

## Pages

| Route | Status | Description |
|---|---|---|
| `/` | Live | Event list + real-time agent trace |
| `/history` | Planned | Full run history with search |
| `/integrations/*` | Planned | Per-integration settings |

## How the live trace works

1. `page.jsx` (server component) loads recent runs from Firestore on request
2. Passes them to `EventsClient` as `initialRuns`
3. `EventsClient` opens an `EventSource` to `GET /stream/:runId` on the agent service
4. Each SSE message is a JSON step — rendered immediately as it arrives
5. On reconnect to a completed run, the stream replays all stored steps and closes

## SSE step types rendered

| Type | Display |
|---|---|
| `classify` | Workflow badge + event source/type |
| `reasoning` | Claude thinking text |
| `tool_call` | Tool name chip + input JSON |
| `tool_result` | Result chip |
| `output` | Final output text |
| `error` | Red error message |

## Environment variables

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_AGENT_URL` | Agent Cloud Run URL — used by the browser to open SSE connection |
| `GCP_PROJECT_ID` | Used server-side to read from Firestore |

`NEXT_PUBLIC_AGENT_URL` is baked into the image at build time by the deploy
workflow, which fetches the agent URL from Cloud Run before building.

## Local development

```bash
npm install

NEXT_PUBLIC_AGENT_URL=http://localhost:8080 \
GCP_PROJECT_ID=local-dev \
npm run dev
```

Open http://localhost:3000. The agent service must be running on :8080.

## ESLint

Uses legacy `.eslintrc.json` format with `next/core-web-vitals`. ESLint v9
is not used — `eslint-config-next@14.2.0` requires eslint v7 or v8.

## Deployment

Deployed automatically by `.github/workflows/deploy.yml` on any push to `main`
that changes `services/frontend/**`. The deploy workflow:
1. Fetches the live agent Cloud Run URL
2. Builds the Docker image with `NEXT_PUBLIC_AGENT_URL` as a build arg
3. Pushes to Artifact Registry
4. Deploys to Cloud Run
