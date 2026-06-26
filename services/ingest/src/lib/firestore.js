const { Firestore } = require('@google-cloud/firestore')

const db = new Firestore({ projectId: process.env.GCP_PROJECT_ID })

async function logEvent(event) {
  try {
    await db.collection('events').doc(event.id).set(event)
  } catch (err) {
    console.error(`Failed to log event ${event.id} to Firestore:`, err.message)
  }
}

module.exports = { logEvent }
