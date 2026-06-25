import { Firestore } from '@google-cloud/firestore'

const db = new Firestore({ projectId: process.env.GCP_PROJECT_ID })

/**
 * Write a raw AgentEvent to Firestore for audit purposes.
 * Non-blocking — errors are logged but not thrown so a Firestore
 * hiccup never prevents the Pub/Sub publish from succeeding.
 *
 * @param {import('./normalize.js').AgentEvent} event
 */
export async function logEvent(event) {
  try {
    await db.collection('events').doc(event.id).set(event)
  } catch (err) {
    console.error(`Failed to log event ${event.id} to Firestore:`, err.message)
  }
}
