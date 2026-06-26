let client = null

function getClient() {
  if (!client) {
    const { PubSub } = require('@google-cloud/pubsub')
    client = new PubSub({ projectId: process.env.GCP_PROJECT_ID })
  }
  return client
}

async function publish(event) {
  const topicName = process.env.PUBSUB_TOPIC ?? 'agentwatch-events'
  const topic = getClient().topic(topicName)
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

module.exports = { publish }
