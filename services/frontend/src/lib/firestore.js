import { Firestore } from '@google-cloud/firestore'

const db = new Firestore({ projectId: process.env.GCP_PROJECT_ID })

/**
 * Get the most recent events, newest first.
 * @param {number} limit
 * @returns {Promise<object[]>}
 */
export async function getRecentEvents(limit = 20) {
  const snap = await db.collection('events')
    .orderBy('receivedAt', 'desc')
    .limit(limit)
    .get()
  return snap.docs.map(d => ({ id: d.id, ...d.data() }))
}

/**
 * Get the most recent runs with their status.
 * @param {number} limit
 * @returns {Promise<object[]>}
 */
export async function getRecentRuns(limit = 20) {
  const snap = await db.collection('runs')
    .orderBy('createdAt', 'desc')
    .limit(limit)
    .get()
  return snap.docs.map(d => ({ id: d.id, ...d.data() }))
}

/**
 * Get all steps for a run.
 * @param {string} runId
 * @returns {Promise<object[]>}
 */
export async function getSteps(runId) {
  const snap = await db
    .collection('runs').doc(runId)
    .collection('steps')
    .orderBy('createdAt', 'asc')
    .get()
  return snap.docs.map(d => ({ id: d.id, ...d.data() }))
}
