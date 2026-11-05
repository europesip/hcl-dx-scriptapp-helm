// EUROPESIP · Hello DX: a small Script Application that shows the pattern, not a product.
//  - Who is the user: DX user profile.
//  - What can they see: WCM libraries through the WCM REST API v2, with the user's own permissions.
//  - Which version is deployed: the version of package.json, set at build time, so you can check
//    that a "helm upgrade" really updated the app.
import { useEffect, useState } from 'react'
import { getCurrentUser, getWcmLibraries, type DxUser, type WcmLibrary } from './dx'

declare const __APP_VERSION__: string

function App() {
  const [user, setUser] = useState<DxUser | null>(null)
  const [libraries, setLibraries] = useState<WcmLibrary[] | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    getCurrentUser().then(setUser).catch((e) => setError(String(e.message || e)))
    getWcmLibraries().then(setLibraries).catch((e) => setError(String(e.message || e)))
  }, [])

  return (
    <section className="ehd">
      <header className="ehd-head">
        <h2>Hello DX</h2>
        <span className="ehd-version">Script Application v{__APP_VERSION__}</span>
      </header>

      <p className="ehd-user">
        {user ? <>Signed in as <b>{user.displayName}</b></> : !error && 'Loading user…'}
      </p>

      {error && <p className="ehd-error">{error}</p>}

      <h3>WCM libraries you can read {libraries && <span className="ehd-count">({libraries.length})</span>}</h3>
      {libraries === null && !error && <p>Loading libraries…</p>}
      {libraries && (
        <ul className="ehd-list">
          {libraries.map((l) => (
            <li key={l.id}>{l.title}</li>
          ))}
        </ul>
      )}

      <footer className="ehd-foot">
        Deployed with Helm and DXClient ·{' '}
        <a href="https://github.com/europesip/hcl-dx-scriptapp-helm" target="_blank" rel="noopener">
          source
        </a>
      </footer>
    </section>
  )
}

export default App
