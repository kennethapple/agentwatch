import { PubSub } from '@google-cloud/pubsub'

const client = new PubSub({ projectId: process.env.GCP_PROJECT_ID })
const topicName = process.env.PUBSUB_TOPIC ?? 'agentwatch-events'

/**
 * Publish an AgentEvent to the Pub/Sub events topic.
 * @param {import('./normalize.js').AgentEvent} event
 */
export async function publish(event) {
  const topic = client.topic(topicName)
  const data = Buffer.from(JSON.stringify(event))

  const messageId = await topic.publishMessage({
    data,
    attributes: {
      source: event.source,
      type: event.type,
      eventId: event.id,
    },
  })

  console.log(`Published event ${event.id} (${event.type}) → messageId ${messageId}`)
  return messageId
}
