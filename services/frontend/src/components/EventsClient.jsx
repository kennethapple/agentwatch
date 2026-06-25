'use client'

import { useState, useEffect, useRef } from 'react'

const AGENT_URL = process.env.NEXT_PUBLIC_AGENT_URL ?? 'http://localhost:8080'

const STEP_META = {
  classify:    { label: 'Classify', icon: '◈', iconClass: 'step-icon-classify' },
  reasoning:   { label: 'Reasoning', icon: '◉', iconClass: 'step-icon-reasoning' },
  tool_call:   { label: 'Tool call', icon: '⬡', iconClass: 'step-icon-tool' },
  tool_result: { label: 'Tool result', icon: '✓', iconClass: 'step-icon-result' },
  output:      { label: 'Output', icon: '★', iconClass: 'step-icon-output' },
  error:       { label: 'Error', icon: '✕', iconClass: 'step-icon-reasoning' },
}

function timeSince(iso) {
  if (!iso) return ''
  const diff = (Date.now() - new Date(iso).getTime()) / 1000
  if (diff < 60) return `${Math.round(diff)}s ago`
  if (diff < 3600) return `${Math.round(diff / 60)}m ago`
  return `${Math.round(diff / 3600)}h ago`
}

function StatusDot({ status }) {
  return <span className={`dot dot-${status === 'running' ? 'running' : status === 'done' ? 'done' : 'failed'}`} />
}

function SourceIcon({ source }) {
  const icons = { gmail: '✉', slack: '#', calendar: '◻', crm: '◈' }
  return <span>{icons[source] ?? '⚡'}</span>
}

function StepView({ step }) {
  const meta = STEP_META[step.type] ?? { label: step.type, icon: '·', iconClass: 'step-icon-reasoning' }
  return (
    <div className="step">
      <div className={`step-icon ${meta.iconClass}`}>{meta.icon}</div>
      <div className="step-body">
        <div className="step-label">{meta.label}</div>
        <div className="step-content">
          {step.type === 'tool_call' && (
            <>
              <span className="step-chip chip-tool">{step.tool}</span>
              {step.input && (
                <pre style={{ marginTop: 6, fontSize: 11, opacity: 0.7, whiteSpace: 'pre-wrap' }}>
                  {JSON.stringify(step.input, null, 2)}
                </pre>
              )}
            </>
          )}
          {step.type === 'tool_result' && (
            <span className="step-chip chip-result">
              {typeof step.content === 'string' ? step.content : JSON.stringify(step.content)}
            </span>
          )}
          {(step.type === 'reasoning' || step.type === 'output') && step.content}
          {step.type === 'classify' && (
            <>
              <span className="step-chip chip-tool">{step.workflow}</span>
              {' '}
              <span style={{ fontSize: 12, opacity: 0.6 }}>{step.event?.source} · {step.event?.type}</span>
            </>
          )}
          {step.type === 'error' && (
            <span style={{ color: 'var(--color-red)' }}>{step.content}</span>
          )}
        </div>
      </div>
    </div>
  )
}

export default function EventsClient({ initialRuns }) {
  const [runs, setRuns] = useState(initialRuns)
  const [selectedRun, setSelectedRun] = useState(initialRuns[0] ?? null)
  const [steps, setSteps] = useState([])
  const [streaming, setStreaming] = useState(false)
  const esRef = useRef(null)
  const traceEndRef = useRef(null)

  // Auto-scroll trace to bottom
  useEffect(() => {
    traceEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [steps])

  // Subscribe to SSE when a run is selected
  useEffect(() => {
    if (!selectedRun) return

    // Close any existing stream
    esRef.current?.close()
    setSteps([])
    setStreaming(false)

    const url = `${AGENT_URL}/stream/${selectedRun.runId ?? selectedRun.id}`
    const es = new EventSource(url)
    esRef.current = es

    if (selectedRun.status === 'running') setStreaming(true)

    es.onmessage = (e) => {
      const step = JSON.parse(e.data)
      if (step.type === 'done') {
        setStreaming(false)
        setRuns(prev => prev.map(r =>
          (r.runId ?? r.id) === selectedRun.runId ?? selectedRun.id
            ? { ...r, status: 'done' }
            : r
        ))
        es.close()
        return
      }
      setSteps(prev => [...prev, step])
    }

    es.onerror = () => {
      setStreaming(false)
      es.close()
    }

    return () => es.close()
  }, [selectedRun?.runId ?? selectedRun?.id])

  const runningRuns = runs.filter(r => r.status === 'running')
  const selectedId = selectedRun?.runId ?? selectedRun?.id

  return (
    <>
      {/* Topbar */}
      <div className="topbar">
        <div className="topbar-title">Live events</div>
        {runningRuns.length > 0 && (
          <span className="badge badge-running">{runningRuns.length} running</span>
        )}
      </div>

      <div className="events-layout">
        {/* Event list */}
        <div className="event-list">
          <div className="event-list-label">Recent runs</div>
          {runs.length === 0 && (
            <div style={{ padding: '12px 6px', fontSize: 12, color: 'var(--color-text-tertiary)' }}>
              No runs yet. Events will appear here automatically.
            </div>
          )}
          {runs.map(run => {
            const id = run.runId ?? run.id
            return (
              <div
                key={id}
                className={`event-card ${id === selectedId ? 'active' : ''}`}
                onClick={() => setSelectedRun(run)}
              >
                <div className="event-source">
                  <StatusDot status={run.status} />
                  <SourceIcon source={run.source} />
                  {run.source} · {timeSince(run.createdAt)}
                </div>
                <div className="event-title">{run.type?.replace(`${run.source}.`, '') ?? 'Event'}</div>
                <div className="event-meta">{run.status}</div>
              </div>
            )
          })}
        </div>

        {/* Trace panel */}
        <div className="trace-panel">
          {!selectedRun ? (
            <div className="empty-state">
              <div className="empty-state-title">No run selected</div>
              <div className="empty-state-sub">Select an event from the left to see the agent trace.</div>
            </div>
          ) : (
            <>
              <div className="trace-header">
                <div className="trace-title">
                  {selectedRun.type ?? 'Agent run'}
                </div>
                <span className={`badge badge-${selectedRun.status}`}>
                  {streaming ? 'Running…' : selectedRun.status}
                </span>
              </div>

              {steps.length === 0 && streaming && (
                <div style={{ fontSize: 13, color: 'var(--color-text-tertiary)' }}>
                  Agent starting<span className="cursor" />
                </div>
              )}

              {steps.map((step, i) => (
                <StepView key={i} step={step} />
              ))}

              {streaming && steps.length > 0 && (
                <div style={{ fontSize: 13, color: 'var(--color-text-tertiary)', paddingLeft: 36 }}>
                  <span className="cursor" />
                </div>
              )}

              <div ref={traceEndRef} />
            </>
          )}
        </div>
      </div>
    </>
  )
}
