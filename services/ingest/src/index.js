import { http } from '@google-cloud/functions-framework'
import { gmailHandler } from './sources/gmail.js'
import { slackHandler } from './sources/slack.js'

// Register HTTP handlers with the Functions Framework.
// This is required when using ES modules ("type": "module") with GCF v2.
http('gmailHandler', gmailHandler)
http('slackHandler', slackHandler)

// Also export for direct import in tests
export { gmailHandler, slackHandler }
