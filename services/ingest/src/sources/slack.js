const { validateSlackSignature } = require('../lib/validate.js')
const { normalize } = require('../lib/normalize.js')
const { publish } = require('../lib/pubsub.js')
const { logEvent } = require('../lib/firestore.js')

async function slackHandler(req, res) {
  if (req.body?.type === 'url_verification') {
    return res.status(200).json({ challenge: req.body.challenge })
  }

  if (!validateSlackSignature(req, process.env.SLACK_SIGNING_SECRET)) {
    console.warn('Slack: invalid request signature')
    return res.status(401).send('Unauthorized')
  }

  const { event, team_id: teamId } = req.body ?? {}
  if (!event?.type) {
    return res.status(400).send('Bad request: missing event.type')
  }

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

  await Promise.all([publish(agentEvent), logEvent(agentEvent)])
  res.status(200).send('ok')
}

module.exports = { slackHandler }
