// Calls to HCL DX from the browser, AS THE USER who sees the page.
// The Script Application is served by DX itself (same host), so the browser sends the user's
// DX session cookie (LtpaToken2) with every request: no tokens, no CORS, no secrets in the code.
// Whatever the user may not see, DX does not return.

const CONTENT_HANDLER = '/wps/mycontenthandler'

export interface DxUser {
  id: string            // distinguished name, e.g. uid=andres,ou=people,dc=...
  displayName: string   // cn, or uid when there is no cn
}

export interface WcmLibrary {
  id: string
  title: string
  lastModified: string
}

/** Current user, from the DX user profile (Atom/XML). */
export async function getCurrentUser(): Promise<DxUser> {
  const res = await fetch(`${CONTENT_HANDLER}/um/secure/currentuser/profile?expandRefs=true`, {
    credentials: 'same-origin',
  })
  if (!res.ok) throw new Error(`DX profile: HTTP ${res.status}`)
  const xml = new DOMParser().parseFromString(await res.text(), 'application/xml')
  const attr = (name: string) =>
    Array.from(xml.getElementsByTagNameNS('*', 'attribute'))
      .find((a) => a.getAttribute('name') === name)
      ?.textContent?.trim() || ''
  const id = xml.getElementsByTagNameNS('*', 'title')[0]?.textContent?.trim() || ''
  return { id, displayName: attr('cn') || attr('uid') || id }
}

// WCM REST v2 returns some texts as a plain string and others as {lang, value} (seen on CF239 in the
// same list of libraries): always read them through text(). React cannot render the object.
type LocalizedText = string | { lang?: string; value?: string } | undefined

function text(t: LocalizedText): string {
  return typeof t === 'string' ? t : t?.value ?? ''
}

/** WCM libraries the user can read (WCM REST API v2). */
export async function getWcmLibraries(limit = 100): Promise<WcmLibrary[]> {
  const res = await fetch(`${CONTENT_HANDLER}/wcmrest-v2/libraries?limit=${limit}`, {
    credentials: 'same-origin',
    headers: { Accept: 'application/json' },
  })
  if (!res.ok) throw new Error(`WCM libraries: HTTP ${res.status}`)
  const data = await res.json()
  return (data['library-entries'] || []).map((l: { id: string; title: LocalizedText; lastModified: string }) => ({
    id: l.id,
    title: text(l.title),
    lastModified: l.lastModified,
  }))
}
