import './globals.css'

export const metadata = {
  title: 'AgentWatch',
  description: 'Real-time AI agent event monitor',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>
        <div className="app-shell">
          <aside className="sidebar">
            <div className="sidebar-header">
              <span className="logo">⚡ AgentWatch</span>
            </div>
            <nav className="sidebar-nav">
              <a href="/" className="nav-item active">
                <span className="nav-icon">⊞</span> Overview
              </a>
              <a href="/events" className="nav-item">
                <span className="nav-icon">⚡</span> Live events
              </a>
              <a href="/history" className="nav-item">
                <span className="nav-icon">⏱</span> Run history
              </a>
              <div className="nav-section">Integrations</div>
              <a href="/integrations/gmail" className="nav-item">
                <span className="nav-icon">✉</span> Gmail
              </a>
              <a href="/integrations/slack" className="nav-item">
                <span className="nav-icon">#</span> Slack
              </a>
              <a href="/integrations/calendar" className="nav-item">
                <span className="nav-icon">◻</span> Calendar
              </a>
            </nav>
            <div className="sidebar-footer">
              <a href="/settings" className="nav-item">
                <span className="nav-icon">⚙</span> Settings
              </a>
            </div>
          </aside>
          <main className="main-content">
            {children}
          </main>
        </div>
      </body>
    </html>
  )
}
