// EUROPESIP · Hello DX: a proof of concept, not a product. It shows:
//  1. Who is signed in: DX user profile API.
//  2. Which WCM libraries they can read: WCM REST API v2, with the user's own permissions.
//  And which version is deployed (package.json, set at build time), so you can check that a
//  "helm upgrade" really updated the app.
import { useEffect, useState } from 'react'
import { getCurrentUser, getWcmLibraries, type DxUser, type WcmLibrary } from './dx'
import { t } from './i18n'

declare const __APP_VERSION__: string
const REPO = 'https://github.com/europesip/hcl-dx-scriptapp-helm'

function App() {
  const [user, setUser] = useState<DxUser | null>(null)
  const [libraries, setLibraries] = useState<WcmLibrary[] | null>(null)
  const [userError, setUserError] = useState('')
  const [libError, setLibError] = useState('')

  useEffect(() => {
    getCurrentUser().then(setUser).catch((e) => setUserError(String(e.message || e)))
    getWcmLibraries().then(setLibraries).catch((e) => setLibError(String(e.message || e)))
  }, [])

  return (
    <section className="ehd">
      <header className="ehd-head">
        <h2>Hello DX</h2>
        <span className="ehd-version">Script Application v{__APP_VERSION__}</span>
      </header>
      <p className="ehd-intro">{t.intro}</p>

      <div className="ehd-block">
        <h3><span className="ehd-num">1</span>{t.userTitle}</h3>
        <p className="ehd-api">{t.userApi} · <code>/wps/mycontenthandler/um/secure/currentuser/profile</code></p>
        {userError ? <p className="ehd-error">{userError}</p>
          : <p>{user ? <>{t.signedInAs} <b>{user.displayName}</b></> : t.userLoading}</p>}
      </div>

      <div className="ehd-block">
        <h3>
          <span className="ehd-num">2</span>{t.libTitle}
          {libraries && <span className="ehd-count"> ({libraries.length})</span>}
        </h3>
        <p className="ehd-api">{t.libApi} · <code>/wps/mycontenthandler/wcmrest-v2/libraries</code></p>
        {libError && <p className="ehd-error">{libError}</p>}
        {libraries === null && !libError && <p>{t.libLoading}</p>}
        {libraries && (
          <ul className="ehd-list">
            {libraries.map((l) => <li key={l.id}>{l.title}</li>)}
          </ul>
        )}
      </div>

      <footer className="ehd-foot">
        {t.more} <a href={REPO} target="_blank" rel="noopener">github.com/europesip/hcl-dx-scriptapp-helm</a>
      </footer>
    </section>
  )
}

export default App
