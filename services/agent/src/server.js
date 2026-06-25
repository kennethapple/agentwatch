import express from 'express'
import { runRoute } from './routes/run.js'
import { streamRoute } from './routes/stream.js'
import { healthRoute } from './routes/health.js'

const app = express()
app.use(express.json())

// POST /run     — Pub/Sub push subscription endpoint
// GET  /stream/:runId — SSE stream for a specific agent run
// GET  /health  — liveness probe for Cloud Run
app.post('/run', runRoute)
app.get('/stream/:runId', streamRoute)
app.get('/health', healthRoute)

const PORT = process.env.PORT ?? 8080
app.listen(PORT, () => {
  console.log(`Agent service listening on :${PORT}`)
})
