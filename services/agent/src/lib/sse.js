/**
 * SSE manager — keeps a map of runId → Set<sendFn> so multiple
 * browser tabs can watch the same run simultaneously.
 *
 * Usage:
 *   sseManager.subscribe(runId, sendFn)      // called from stream route
 *   sseManager.broadcast(runId, step)        // called from agent runner
 *   sseManager.unsubscribe(runId, sendFn)    // called on client disconnect
 *   sseManager.close(runId)                  // called when run completes
 */
class SSEManager {
  constructor() {
    /** @type {Map<string, Set<function>>} */
    this._subscribers = new Map()
  }

  subscribe(runId, sendFn) {
    if (!this._subscribers.has(runId)) {
      this._subscribers.set(runId, new Set())
    }
    this._subscribers.get(runId).add(sendFn)
  }

  unsubscribe(runId, sendFn) {
    const subs = this._subscribers.get(runId)
    if (!subs) return
    subs.delete(sendFn)
    if (subs.size === 0) this._subscribers.delete(runId)
  }

  broadcast(runId, data) {
    const subs = this._subscribers.get(runId)
    if (!subs || subs.size === 0) return
    for (const send of subs) {
      try {
        send(data)
      } catch (err) {
        console.warn(`SSE send failed for run ${runId}:`, err.message)
        subs.delete(send)
      }
    }
  }

  close(runId) {
    this.broadcast(runId, { type: 'done', runId })
    this._subscribers.delete(runId)
  }
}

// Singleton — shared across all routes in this process
export const sseManager = new SSEManager()
