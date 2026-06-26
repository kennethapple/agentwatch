const { http } = require('@google-cloud/functions-framework')
const { gmailHandler } = require('./sources/gmail.js')
const { slackHandler } = require('./sources/slack.js')

http('gmailHandler', gmailHandler)
http('slackHandler', slackHandler)
