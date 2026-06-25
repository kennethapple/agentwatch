import { google } from 'googleapis'
import { validateGmailToken } from '../lib/validate.js'
import { normalize } from '../lib/normalize.js'
import { publish } from '../lib/pubsub.js'
import { logEvent } from '../lib/firestore.js'

/**
 * Cloud Function: Gmail webhook handler.
 *
 * Google sends a Pub/Sub push notification when new mail arrives
 * (set up via gmail.users.watch). The notification contains a base64-
 * encoded JSON body with the user's email and a historyId. We fetch
 * the full thread and normalize it before publishing to our topic.
 */
export async function gmailHandler(req, res) {
  // Validate push token
  if (!validateGmailToken(req, process.env.GMAIL_WEBHOOK_TOKEN)) {
    console.warn('Gmail: invalid push token')
    return res.status(401).send('Unauthorized')
  }

  // Decode the Pub/Sub message from Google
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

  // Fetch the relevant thread via Gmail API (using Application Default Credentials)
  let thread = null
  try {
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/gmail.readonly'],
    })
    const gmail = google.gmail({ version: 'v1', auth })

    // List history since the last known historyId to find new messages
    const historyRes = await gmail.users.history.list({
      userId: emailAddress,
      startHistoryId: String(Number(historyId) - 1),
      historyTypes: ['messageAdded'],
    })

    const messages = historyRes.data.history
      ?.flatMap(h => h.messagesAdded ?? [])
      .map(m => m.message) ?? []

    if (messages.length === 0) {
      // No new messages — acknowledge and exit
      return res.status(200).send('ok')
    }

    // Fetch the first new message's thread
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
    // Still publish with what we have — agent can handle partial data
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

  await Promise.all([
    publish(event),
    logEvent(event),
  ])

  res.status(200).send('ok')
}
