/**
 * Decode a Pub/Sub push envelope into an AgentEvent.
 *
 * Pub/Sub push delivers:
 * {
 *   message: {
 *     data: "<base64-encoded JSON>",
 *     attributes: { source, type, eventId },
 *     messageId: "...",
 *   },
 *   subscription: "..."
 * }
 */
export function decodeEvent(body) {
  const data = body?.message?.data
  if (!data) throw new Error('Missing message.data in Pub/Sub envelope')

  const decoded = Buffer.from(data, 'base64').toString('utf8')
  const event = JSON.parse(decoded)

  if (!event.id || !event.source || !event.type) {
    throw new Error('Invalid AgentEvent: missing id, source, or type')
  }

  return event
}
