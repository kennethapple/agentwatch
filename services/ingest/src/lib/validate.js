import crypto from 'crypto'

/**
 * Validate a Slack request signature.
 * https://api.slack.com/authentication/verifying-requests-from-slack
 *
 * @param {import('@google-cloud/functions-framework').Request} req
 * @param {string} signingSecret
 * @returns {boolean}
 */
export function validateSlackSignature(req, signingSecret) {
  const timestamp = req.headers['x-slack-request-timestamp']
  const signature = req.headers['x-slack-signature']

  if (!timestamp || !signature) return false

  // Reject requests older than 5 minutes to prevent replay attacks
  const age = Math.abs(Date.now() / 1000 - Number(timestamp))
  if (age > 300) return false

  const rawBody = req.rawBody ?? JSON.stringify(req.body)
  const baseString = `v0:${timestamp}:${rawBody}`
  const expected = 'v0=' + crypto
    .createHmac('sha256', signingSecret)
    .update(baseString)
    .digest('hex')

  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))
}

/**
 * Validate a Gmail Pub/Sub push notification token.
 * Google includes a ?token= query param that matches the value you set
 * when calling gmail.users.watch().
 *
 * @param {import('@google-cloud/functions-framework').Request} req
 * @param {string} expectedToken
 * @returns {boolean}
 */
export function validateGmailToken(req, expectedToken) {
  const token = req.query.token ?? req.body?.message?.attributes?.token
  if (!token || !expectedToken) return false
  return crypto.timingSafeEqual(Buffer.from(token), Buffer.from(expectedToken))
}
