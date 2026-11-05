// Texts of the app in English and Spanish.
const en = {
  intro:
    'Proof of concept by EUROPESIP: how to deploy a Script Application to HCL DX with a single "helm install", and how it works with DX through its REST APIs, as the signed-in user. It shows two integrations:',
  userTitle: 'Who is signed in',
  userApi: 'DX user profile API',
  userLoading: 'Loading user…',
  signedInAs: 'Signed in as',
  libTitle: 'WCM libraries you can read',
  libApi: 'WCM REST API v2 · DX applies your own permissions',
  libLoading: 'Loading libraries…',
  more: 'How it was built and deployed (source, Helm chart and instructions):',
}
const es: typeof en = {
  intro:
    'Prueba de concepto de EUROPESIP: cómo desplegar una Script Application en HCL DX con un solo "helm install", y cómo trabaja con DX a través de sus API REST, como el usuario que ha iniciado sesión. Muestra dos integraciones:',
  userTitle: 'Quién ha iniciado sesión',
  userApi: 'API del perfil de usuario de DX',
  userLoading: 'Cargando el usuario…',
  signedInAs: 'Has iniciado sesión como',
  libTitle: 'Bibliotecas de WCM que puedes leer',
  libApi: 'API REST v2 de WCM · DX aplica tus propios permisos',
  libLoading: 'Cargando las bibliotecas…',
  more: 'Cómo se ha construido y desplegado (código, chart de Helm e instrucciones):',
}

export type Texts = typeof en

/**
 * Language of the app, in this order:
 *  1. the user's preferred language in the DX profile (attribute preferredLanguage);
 *  2. the language DX chose for the page (<html lang>): DX already resolves it from the user's
 *     preference, the browser and the portal default;
 *  3. the browser.
 * Spanish gets Spanish; anything else, English.
 */
export function texts(preferredLanguage = ''): Texts {
  const lang = (preferredLanguage || document.documentElement.lang || navigator.language || 'en').toLowerCase()
  return lang.startsWith('es') ? es : en
}
