export function healthRoute(_req, res) {
  res.status(200).json({ status: 'ok', ts: new Date().toISOString() })
}
