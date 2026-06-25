import { Firestore } from '@google-cloud/firestore'

const db = new Firestore({ projectId: process.env.GCP_PROJECT_ID })

// ── Runs ──────────────────────────────────────────────────────────────────────

/**
 * Create a new run document.
 * @param {{ runId: string, eventId: string, event: object }} opts
 */
export async function createRun({ runId, eventId, event }) {
  await db.collection('runs').doc(runId).set({
    runId,
    eventId,
    source: event.source,
    type: event.type,
    status: 'running',
    createdAt: Firestore.Timestamp.now(),
  })
}

/**
 * Update a run's status (and optionally other fields).
 * @param {string} runId
 * @param {object} fields
 */
export async function updateRun(runId, fields) {
  await db.collection('runs').doc(runId).update({
    ...fields,
    updatedAt: Firestore.Timestamp.now(),
  })
}

/**
 * Get a run document.
 * @param {string} runId
 * @returns {Promise<object|null>}
 */
export async function getRun(runId) {
  const doc = await db.collection('runs').doc(runId).get()
  return doc.exists ? doc.data() : null
}

// ── Steps ─────────────────────────────────────────────────────────────────────

/**
 * Append a step to a run's steps subcollection.
 * @param {string} runId
 * @param {{ type: string, content: any }} step
 * @returns {Promise<string>} stepId
 */
export async function addStep(runId, step) {
  const ref = await db
    .collection('runs').doc(runId)
    .collection('steps').add({
      ...step,
      createdAt: Firestore.Timestamp.now(),
    })
  return ref.id
}

/**
 * Get all steps for a run, ordered by creation time.
 * @param {string} runId
 * @returns {Promise<object[]>}
 */
export async function getRunSteps(runId) {
  const snap = await db
    .collection('runs').doc(runId)
    .collection('steps')
    .orderBy('createdAt', 'asc')
    .get()

  return snap.docs.map(d => ({ stepId: d.id, ...d.data() }))
}
