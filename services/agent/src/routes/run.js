import { v4 as uuidv4 } from 'uuid'
import { decodeEvent } from '../lib/pubsub.js'
import { createRun, updateRun } from '../lib/firestore.js'
import { runAgent } from '../lib/agent.js'
import { sseManager } from '../lib/sse.js'

/**
 * POST /run
 *
 * Called by Pub/Sub push subscription with a base64-encoded AgentEvent.
 * Responds 200 immediately (Pub/Sub requires < 10s acknowledgement),
 * then runs the agent asynchronously.
 */
export async function runRoute(req, res) {
  // Decode Pub/Sub envelope
  let event
  try {
    event = decodeEvent(req.body)
  } catch (err) {
    console.error('Failed to decode Pub/Sub message:', err.message)
    return res.status(400).send('Bad request')
  }

  const runId = uuidv4()

  // Acknowledge Pub/Sub immediately — must respond within 10s
  res.status(200).json({ runId })

  // Create the run document in Firestore
  await createRun({ runId, eventId: event.id, event })

  // Run agent asynchronously — don't await
  runAgent({ runId, event, sseManager })
    .then(() => updateRun(runId, { status: 'done' }))
    .catch(async (err) => {
      console.error(`Run ${runId} failed:`, err.message)
      await updateRun(runId, { status: 'failed', error: err.message })
      sseManager.broadcast(runId, { type: 'error', content: err.message })
      sseManager.close(runId)
    })
}
