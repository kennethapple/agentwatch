const crypto = require('crypto')

function validateSlackSignature(req, signingSecret) {
  const timestamp = req.headers['x-slack-request-timestamp']
  const signature = req.headers['x-slack-signature']
  if (!timestamp || !signature) return false
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

function validateGmailToken(req, expectedToken) {
  const token = req.query?.token ?? req.body?.message?.attributes?.token
  if (!token || !expectedToken) return false
  return crypto.timingSafeEqual(Buffer.from(token), Buffer.from(expectedToken))
}

module.exports = { validateSlackSignature, validateGmailToken }
