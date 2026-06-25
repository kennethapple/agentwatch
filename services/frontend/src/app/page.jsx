import { getRecentRuns } from '../lib/firestore.js'
import EventsClient from '../components/EventsClient.jsx'

// Serialize Firestore Timestamps to strings for client components
function serializeRun(run) {
  return {
    ...run,
    createdAt: run.createdAt?.toDate?.()?.toISOString() ?? run.createdAt ?? null,
    updatedAt: run.updatedAt?.toDate?.()?.toISOString() ?? run.updatedAt ?? null,
  }
}

export default async function HomePage() {
  let runs = []
  try {
    const raw = await getRecentRuns(20)
    runs = raw.map(serializeRun)
  } catch (err) {
    // Firestore not reachable locally — render empty state
    console.warn('Firestore unavailable:', err.message)
  }

  return <EventsClient initialRuns={runs} />
}
