/**
 * Workflow registry.
 *
 * Each workflow defines:
 *   match(event)    → boolean   — whether this workflow handles the event
 *   systemPrompt    → string    — Claude system prompt for this event type
 *   tools           → string[]  — MCP tool names available to this workflow
 */

const workflows = [
  {
    name: 'gmail-email',
    match: (e) => e.source === 'gmail' && e.type === 'gmail.email_received',
    tools: ['gmail_get_thread', 'gmail_send_reply', 'crm_get_contact', 'calendar_check_availability'],
    systemPrompt: `You are an intelligent email assistant. When you receive a new email notification:

1. Use gmail_get_thread to read the full email thread.
2. Use crm_get_contact to look up the sender and understand their context.
3. Reason about what action is needed: does this require a reply, a calendar invite, a task, or just filing?
4. If a reply is warranted, draft one and use gmail_send_reply to send it.
5. If a meeting is requested, use calendar_check_availability to find a slot and include it in the reply.

Always think step by step before acting. Explain your reasoning before each tool call.`,
  },

  {
    name: 'slack-message',
    match: (e) => e.source === 'slack' && e.type === 'slack.message',
    tools: ['slack_get_channel_history', 'slack_post_message', 'slack_get_user_info'],
    systemPrompt: `You are an intelligent Slack assistant. When you receive a new Slack message:

1. Use slack_get_channel_history to get context from recent messages in the channel.
2. Use slack_get_user_info to understand who sent the message.
3. Determine if the message requires a response, escalation, or action.
4. If a response is warranted, use slack_post_message to reply in the thread.

Keep responses concise and appropriate to Slack's informal tone.
Always explain your reasoning before acting.`,
  },

  {
    name: 'calendar-upcoming',
    match: (e) => e.source === 'calendar',
    tools: ['calendar_get_event', 'gmail_send_reply', 'slack_post_message'],
    systemPrompt: `You are a meeting preparation assistant. When an upcoming calendar event is detected:

1. Use calendar_get_event to get the full event details and attendees.
2. Consider what preparation would be valuable: agenda, briefing docs, attendee context.
3. Draft and send a preparation brief via gmail_send_reply or slack_post_message as appropriate.

Be concise and actionable. Focus on what the person needs to know before the meeting.`,
  },
]

/**
 * Find the workflow that matches the given event.
 * Falls back to a generic workflow if nothing matches.
 *
 * @param {import('../../ingest/src/lib/normalize.js').AgentEvent} event
 * @returns {{ name: string, systemPrompt: string, tools: string[] }}
 */
export function getWorkflow(event) {
  const match = workflows.find(w => w.match(event))
  if (match) return match

  // Generic fallback
  return {
    name: 'generic',
    tools: [],
    systemPrompt: `You are a general-purpose agent. Analyze the following event and describe what actions, if any, should be taken. Think step by step.`,
  }
}
