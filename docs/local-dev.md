# Local development

## Prerequisites

```bash
node -v   # 20+
gcloud --version
terraform --version  # 1.7+
```

## Running services locally

### 1. Set environment variables

```bash
cp .env.example .env
# Fill in ANTHROPIC_API_KEY, GCP_PROJECT_ID, etc.
```

### 2. Start the agent service

```bash
cd services/agent
npm install
npm run dev   # runs on :8080
```

### 3. Start the frontend

```bash
cd services/frontend
npm install
npm run dev   # runs on :3000, proxies /stream to :8080
```

### 4. Simulate an event (no real webhook needed)

```bash
cd services/ingest
npm install
node scripts/simulate.js --source gmail --fixture fixtures/email-approval.json
```

This publishes a test event directly to your local agent service via HTTP.

## Using the Pub/Sub emulator

If you want full end-to-end local testing with Pub/Sub:

```bash
gcloud components install pubsub-emulator
gcloud beta emulators pubsub start --project=local-dev

# In a new terminal:
export PUBSUB_EMULATOR_HOST=localhost:8085
export PUBSUB_PROJECT_ID=local-dev
node scripts/create-topics.js   # creates topics on the emulator
```

## Firestore emulator

```bash
npm install -g firebase-tools
firebase emulators:start --only firestore
# Firestore UI: http://localhost:4000
```

Set `FIRESTORE_EMULATOR_HOST=localhost:8080` before starting the agent.

## Environment variables reference

| Variable | Service | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | agent | Claude API key |
| `GCP_PROJECT_ID` | all | GCP project |
| `PUBSUB_TOPIC` | ingest | Topic to publish events to |
| `AGENT_SERVICE_URL` | infra | Cloud Run agent URL (for push sub) |
| `FIRESTORE_EMULATOR_HOST` | agent, frontend | Local Firestore emulator |
| `SLACK_SIGNING_SECRET` | ingest | Slack request signing secret |
| `GMAIL_WEBHOOK_TOKEN` | ingest | Token to validate Gmail push |
| `MCP_SERVERS` | agent | JSON array of MCP server configs |
