const { v4: uuidv4 } = require('uuid')

function normalize({ source, type, payload, rawPayload }) {
  if (!source || !type || !payload) {
    throw new Error('normalize: source, type, and payload are required')
  }
  return {
    id: uuidv4(),
    source,
    type,
    payload,
    rawPayload: rawPayload ?? payload,
    receivedAt: new Date().toISOString(),
  }
}

module.exports = { normalize }
