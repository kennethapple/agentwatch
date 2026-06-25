import { v4 as uuidv4 } from 'uuid'

/**
 * @typedef {Object} AgentEvent
 * @property {string} id          - UUID
 * @property {string} source      - 'gmail' | 'slack' | 'calendar'
 * @property {string} type        - e.g. 'gmail.email_received'
 * @property {object} payload     - normalized, source-specific data
 * @property {object} rawPayload  - original webhook body
 * @property {string} receivedAt  - ISO 8601
 */

/**
 * Construct a normalized AgentEvent from raw webhook data.
 * @param {{ source: string, type: string, payload: object, rawPayload: object }} opts
 * @returns {AgentEvent}
 */
export function normalize({ source, type, payload, rawPayload }) {
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
