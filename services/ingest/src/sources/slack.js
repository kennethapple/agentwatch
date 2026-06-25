import { validateSlackSignature } from '../lib/validate.js'
import { normalize } from '../lib/normalize.js'
import { publish } from '../lib/pubsub.js'
import { logEvent } from '../lib/firestore.js'

/**
 * Cloud Function: Slack webhook handler.
 *
 * Handles Slack Events API callbacks. Slack sends a URL verification
 * challenge on first setup, then real events thereafter.
 *
 * Supported event types:
 *   - message (new message in a channel)
 *   - app_mention (bot mentioned)
 */
export async function slackHandler(req, res) {
  // Slack URL verification challenge (one-time, on app setup)
  if (req.body?.type === 'url_verification') {
    return res.status(200).json({ challenge: req.body.challenge })
  }

  // Validate HMAC signature on all other requests
  if (!validateSlackSignature(req, process.env.SLACK_SIGNING_SECRET)) {
    console.warn('Slack: invalid request signature')
    return res.status(401).send('Unauthorized')
  }

  const { event, team_id: teamId } = req.body ?? {}

  if (!event?.type) {
    return res.status(400).send('Bad request: missing event.type')
  }

  // Skip bot messages and message edits to avoid loops
  if (event.bot_id || event.subtype === 'message_changed') {
    return res.status(200).send('ok')
  }

  const agentEvent = normalize({
    source: 'slack',
    type: `slack.${event.type}`,
    payload: {
      teamId,
      channelId: event.channel,
      channelType: event.channel_type,
      userId: event.user,
      text: event.text,
      ts: event.ts,
      threadTs: event.thread_ts ?? null,
      files: event.files?.map(f => ({ id: f.id, name: f.name, mimetype: f.mimetype })) ?? [],
    },
    rawPayload: req.body,
  })

  await Promise.all([
    publish(agentEvent),
    logEvent(agentEvent),
  ])

  // Slack requires a 200 within 3 seconds
  res.status(200).send('ok')
}
