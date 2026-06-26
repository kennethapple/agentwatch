const { google } = require('googleapis')
const { validateGmailToken } = require('../lib/validate.js')
const { normalize } = require('../lib/normalize.js')
const { publish } = require('../lib/pubsub.js')
const { logEvent } = require('../lib/firestore.js')

async function gmailHandler(req, res) {
  if (!validateGmailToken(req, process.env.GMAIL_WEBHOOK_TOKEN)) {
    console.warn('Gmail: invalid push token')
    return res.status(401).send('Unauthorized')
  }

  const envelope = req.body
  if (!envelope?.message?.data) {
    return res.status(400).send('Bad request: missing message.data')
  }

  let notification
  try {
    const decoded = Buffer.from(envelope.message.data, 'base64').toString('utf8')
    notification = JSON.parse(decoded)
  } catch {
    return res.status(400).send('Bad request: could not decode message')
  }

  const { emailAddress, historyId } = notification
  if (!emailAddress || !historyId) {
    return res.status(400).send('Bad request: missing emailAddress or historyId')
  }

  let thread = null
  try {
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
    })
    const gmail = google.gmail({ version: 'v1', auth })
    const historyRes = await gmail.users.history.list({
      userId: emailAddress,
      startHistoryId: String(Number(historyId) - 1),
      historyTypes: ['messageAdded'],
    })
    const messages = historyRes.data.history
      ?.flatMap(h => h.messagesAdded ?? [])
      .map(m => m.message) ?? []
    if (messages.length === 0) return res.status(200).send('ok')
    const msg = messages[0]
    const threadRes = await gmail.users.threads.get({
      userId: emailAddress,
      id: msg.threadId,
      format: 'metadata',
      metadataHeaders: ['Subject', 'From', 'To', 'Date'],
    })
    thread = threadRes.data
  } catch (err) {
    console.error('Gmail API error:', err.message)
  }

  const headers = thread?.messages?.[0]?.payload?.headers ?? []
  const getHeader = name => headers.find(h => h.name === name)?.value ?? ''

  const event = normalize({
    source: 'gmail',
    type: 'gmail.email_received',
    payload: {
      emailAddress,
      historyId,
      threadId: thread?.id,
      subject: getHeader('Subject'),
      from: getHeader('From'),
      to: getHeader('To'),
      date: getHeader('Date'),
      messageCount: thread?.messages?.length ?? 1,
    },
    rawPayload: envelope,
  })

  await Promise.all([publish(event), logEvent(event)])
  res.status(200).send('ok')
}

module.exports = { gmailHandler }
