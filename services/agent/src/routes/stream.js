import { sseManager } from '../lib/sse.js'
import { getRun, getRunSteps } from '../lib/firestore.js'

/**
 * GET /stream/:runId
 *
 * Server-Sent Events stream. The frontend connects here and receives
 * every agent step as it is written.
 *
 * If the run is already complete, replays all stored steps immediately
 * then closes the connection. If still running, streams live steps.
 */
export async function streamRoute(req, res) {
  const { runId } = req.params

  // SSE headers
  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache')
  res.setHeader('Connection', 'keep-alive')
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.flushHeaders()

  const send = (data) => {
    res.write(`data: ${JSON.stringify(data)}\n\n`)
  }

  // Check if run already exists
  const run = await getRun(runId).catch(() => null)
  if (!run) {
    send({ type: 'error', content: 'Run not found' })
    return res.end()
  }

  // If already done, replay stored steps and close
  if (run.status === 'done' || run.status === 'failed') {
    const steps = await getRunSteps(runId)
    for (const step of steps) send(step)
    send({ type: 'done', runId })
    return res.end()
  }

  // Otherwise subscribe to live SSE manager
  sseManager.subscribe(runId, send)

  // Clean up when client disconnects
  req.on('close', () => {
    sseManager.unsubscribe(runId, send)
  })
}
