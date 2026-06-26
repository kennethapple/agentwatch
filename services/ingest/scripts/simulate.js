#!/usr/bin/env node
/**
 * Simulate an ingest event locally.
 * Usage:
 *   node scripts/simulate.js --source gmail --fixture fixtures/email-approval.json
 *   node scripts/simulate.js --source slack --fixture fixtures/slack-message.json
 */

const { readFileSync } = require('fs')
const { resolve } = require('path')
const { normalize } = require('../src/lib/normalize.js')

const args = process.argv.slice(2)
const getArg = (flag) => { const i = args.indexOf(flag); return i !== -1 ? args[i + 1] : null }

const source = getArg('--source') ?? 'gmail'
const fixturePath = getArg('--fixture') ?? `fixtures/${source}-default.json`
const agentUrl = process.env.AGENT_URL ?? 'http://localhost:8080'

const rawPayload = JSON.parse(readFileSync(resolve(fixturePath), 'utf8'))
const typeMap = { gmail: 'gmail.email_received', slack: 'slack.message', calendar: 'calendar.event_upcoming' }

const event = normalize({
  source,
  type: typeMap[source] ?? `${source}.event`,
  payload: rawPayload,
  rawPayload,
})

console.log(`Simulating ${event.type} event (id: ${event.id})`)
console.log(`Posting to ${agentUrl}/run ...`)

fetch(`${agentUrl}/run`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    message: {
      data: Buffer.from(JSON.stringify(event)).toString('base64'),
      attributes: { source: event.source, type: event.type, eventId: event.id },
    },
  }),
}).then(res => {
  console.log(`Response: ${res.status} ${res.statusText}`)
  console.log(`Watch the run at: ${agentUrl}/stream/${event.id}`)
})
