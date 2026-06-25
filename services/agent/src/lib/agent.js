import Anthropic from '@anthropic-ai/sdk'
import { getWorkflow } from '../workflows/index.js'
import { addStep } from './firestore.js'

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })

/**
 * Load MCP server configs from the MCP_SERVERS env var.
 * Expected format: JSON array of { name: string, url: string }
 *
 * @returns {Array<{ type: 'url', url: string, name: string }>}
 */
function getMcpServers() {
  const raw = process.env.MCP_SERVERS
  if (!raw) return []
  try {
    return JSON.parse(raw).map(s => ({ type: 'url', url: s.url, name: s.name }))
  } catch {
    console.warn('MCP_SERVERS is not valid JSON — running without MCP tools')
    return []
  }
}

/**
 * Run the agent for a given event.
 *
 * Streams Claude's response, emitting each reasoning block and tool call
 * as a step to both Firestore and connected SSE clients.
 *
 * @param {{ runId: string, event: object, sseManager: import('./sse.js').SSEManager }} opts
 */
export async function runAgent({ runId, event, sseManager }) {
  const workflow = getWorkflow(event)
  console.log(`Run ${runId}: using workflow "${workflow.name}" for ${event.type}`)

  // Emit + persist a step
  async function emitStep(step) {
    await addStep(runId, step)
    sseManager.broadcast(runId, step)
  }

  await emitStep({
    type: 'classify',
    content: `Workflow matched: ${workflow.name}`,
    workflow: workflow.name,
    event: { source: event.source, type: event.type, payload: event.payload },
  })

  const mcpServers = getMcpServers()
  const userMessage = `Process this event:\n\n${JSON.stringify(event.payload, null, 2)}`

  // Build request — include MCP servers only if configured
  const request = {
    model: 'claude-sonnet-4-6',
    max_tokens: 4096,
    system: workflow.systemPrompt,
    messages: [{ role: 'user', content: userMessage }],
    ...(mcpServers.length > 0 && { mcp_servers: mcpServers }),
    betas: mcpServers.length > 0 ? ['mcp-client-2025-04-04'] : [],
  }

  // Stream the response
  const stream = await anthropic.beta.messages.stream(request)

  let currentText = ''
  let currentToolName = null
  let currentToolInput = ''

  for await (const event of stream) {
    switch (event.type) {
      case 'content_block_start':
        if (event.content_block.type === 'text') {
          currentText = ''
        } else if (event.content_block.type === 'tool_use') {
          currentToolName = event.content_block.name
          currentToolInput = ''
        }
        break

      case 'content_block_delta':
        if (event.delta.type === 'text_delta') {
          currentText += event.delta.text
        } else if (event.delta.type === 'input_json_delta') {
          currentToolInput += event.delta.partial_json
        }
        break

      case 'content_block_stop':
        if (currentText) {
          await emitStep({ type: 'reasoning', content: currentText.trim() })
          currentText = ''
        } else if (currentToolName) {
          let parsedInput = {}
          try { parsedInput = JSON.parse(currentToolInput) } catch {}
          await emitStep({
            type: 'tool_call',
            tool: currentToolName,
            input: parsedInput,
          })
          currentToolName = null
          currentToolInput = ''
        }
        break

      case 'message_delta':
        if (event.delta.stop_reason === 'end_turn') {
          await emitStep({ type: 'output', content: 'Run complete.' })
        }
        break
    }
  }

  // Final message for tool results if present
  const finalMessage = await stream.finalMessage()
  const toolResults = finalMessage.content.filter(b => b.type === 'tool_result')
  for (const result of toolResults) {
    await emitStep({
      type: 'tool_result',
      tool: result.tool_use_id,
      content: result.content,
    })
  }

  sseManager.close(runId)
}
