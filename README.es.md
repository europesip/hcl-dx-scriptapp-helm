# Script Applications para HCL DX, desplegadas con Helm

[English](README.md)

**Despliega una Script Application de HCL DX con `helm install`, como el resto de tu Kubernetes.**

Una Script Application es HTML, JavaScript y CSS guardados en el Web Content Manager (WCM) de DX:
es la forma de construir aplicaciones propias en **HCL DX Compose**, donde los portlets Java propios
necesitan el *Java Transition Module*, que se licencia aparte. HCL las despliega con la herramienta
de línea de comandos DXClient. Este repositorio envuelve ese paso en un chart de Helm, para que una
Script Application tenga versión, chart y `helm upgrade`, y pueda ir junto a los servicios de
backend con los que habla.

Contiene:

| Carpeta | Qué es |
|---|---|
| [app/](app) | **Hello DX**, una pequeña Script Application en React (Vite, TypeScript), creada a partir de la plantilla `create-dx-script-app` de HCL. Muestra quién es el usuario y qué bibliotecas de WCM puede leer, llamando a DX **como ese usuario** |
| [app/Dockerfile](app/Dockerfile) | La **imagen del bundle**: una imagen mínima que solo lleva la aplicación compilada |
| [chart/hcl-dx-scriptapp](chart/hcl-dx-scriptapp) | El **chart de Helm**: un Job que sube la aplicación a DX con DXClient |

Es un ejemplo, no un producto, y no es software de HCL. Probado en HCL DX Compose CF239 (DXClient
`v95_CF239_20261103-1404`).

## Cómo funciona

```
helm upgrade --install hello-dx oci://ghcr.io/europesip/charts/hcl-dx-scriptapp ...
   │
   └─ Job (hook de Helm, tras cada install y upgrade)
        ├─ initContainer  imagen del bundle ─► copia la app compilada (index.html, assets/) a un volumen
        └─ container      DXClient de HCL  ─► espera a DX y hace
                                              dxclient deploy-scriptapplication push
                                              ─► WCM: Script Application Library/Script Applications/<nombre>
```

- **Primera instalación:** el push crea la Script Application en WCM. La añades a una página una vez.
- **Cada upgrade:** el push actualiza **el mismo** elemento de WCM (mismo ID de contenido), así que
  todas las páginas que la usan muestran la versión nueva. Sin reiniciar DX.
- **Por qué una imagen** y no un ConfigMap: un ConfigMap está limitado a 1 MiB, igual que el Secret
  donde Helm guarda cada release, así que un bundle de JavaScript no cabe en el chart. Una imagen no
  tiene límite práctico, se versiona por su etiqueta y viene del mismo registro que todo lo demás
  (también en espejos *air-gapped*).

## Instalarlo en tu clúster

Necesitas `kubectl` y `helm` (3.8+ o 4) contra el clúster donde corre DX, y un usuario de DX.

**1. Credenciales de un usuario de DX** con acceso de Editor a la *Script Application Library*
(fuera de un laboratorio, un usuario técnico, no `wpsadmin`). Vale cualquier namespace; el Job solo
habla con DX por HTTPS:

```bash
kubectl -n dx-shared create secret generic scriptapp-dx \
  --from-literal=username='<usuario de DX>' --from-literal=password='<contraseña>'
```

**2. Solo si el certificado de DX es autofirmado o de una CA privada:** un Secret con esa CA, clave
`ca.crt`. En los [labs de HCL DX Compose](https://github.com/europesip/hcl-dx-compose-labs) el
certificado es autofirmado, así que el propio certificado es la CA:

```bash
kubectl -n dx-demo get secret dx-tls-cert -o jsonpath='{.data.tls\.crt}' | base64 -d > dx-ca.crt
kubectl -n dx-shared create secret generic scriptapp-dx-ca --from-file=ca.crt=dx-ca.crt
```

**3. Lee la licencia de DXClient** (una licencia de HCL para programas sin garantía) y acéptala con
`dxclient.acceptLicense=true`: el chart no se instala hasta que lo hagas. Para leerla:

```bash
docker run --rm hclcr.io/dx-public/dxclient:v95_CF239_20261103-1404 /dxclient/bin/dxclient accept-license
```

**4. Instalar:**

```bash
helm upgrade --install hello-dx oci://ghcr.io/europesip/charts/hcl-dx-scriptapp --version 0.1.0 \
  -n dx-shared \
  --set dx.host=dx.example.com \
  --set dx.credentialsSecret=scriptapp-dx \
  --set dx.caSecret=scriptapp-dx-ca \
  --set dxclient.acceptLicense=true
```

Usa la imagen de DXClient de tu nivel de DX (`--set dxclient.image=hclcr.io/dx-public/dxclient:<tag>`;
las etiquetas están en el repositorio público `dx-public/dxclient` del Harbor de HCL).

**5. Comprobar el push:**

```bash
kubectl -n dx-shared logs job/hello-dx-hcl-dx-scriptapp-push
```

Termina con `OK: 'europesip-hello-dx' is in WCM (content ID ...)`. `helm install` espera al Job y
falla si falla el push.

**6. Añadirla a una página, una vez:** en DX, edita una página, añade un componente, *Script
Applications* → **Hello DX**, y publica. Muestra tu nombre, las bibliotecas de WCM que puedes leer y
la versión desplegada.

**7. Actualizarla:** publica una imagen de bundle nueva (versión nueva de la app) y haz upgrade:

```bash
helm upgrade hello-dx oci://ghcr.io/europesip/charts/hcl-dx-scriptapp --version 0.1.0 -n dx-shared \
  --reuse-values --set bundle.image=ghcr.io/europesip/hcl-dx-scriptapp-helm/europesip-hello-dx:1.0.1
```

**8. Desinstalar:** `helm uninstall hello-dx -n dx-shared` borra el chart, **no la app de WCM**
(puede haber páginas que la usen). El último Job se queda por sus logs: `kubectl -n dx-shared delete
job hello-dx-hcl-dx-scriptapp-push`. Para quitar también la app de DX, con el ID de contenido del
log:

```bash
dxclient undeploy-scriptapplication --dxProtocol https --hostname dx.example.com --dxPort 443 \
  --dxUsername '<usuario>' --dxPassword '<contraseña>' --wcmContentId <ID de contenido> -f
```

## Values

| Value | Por defecto | Qué es |
|---|---|---|
| `dx.host` | (obligatorio) | Nombre de host de DX, tal como lo alcanza el Job (normalmente el público) |
| `dx.credentialsSecret` | (obligatorio) | Secret con `username` y `password` del usuario de DX |
| `dxclient.acceptLicense` | `false` | Tiene que ser `true`: aceptas la licencia de DXClient |
| `dx.caSecret` | `""` | Secret con `ca.crt`, para un certificado autofirmado o de CA privada |
| `dx.insecureSkipTLSVerify` | `false` | Solo laboratorio: no verificar el certificado |
| `dx.virtualPortalContext` | `""` | Subir a un portal virtual |
| `dx.projectContext` | `""` | Subir a un proyecto de WCM en lugar de publicar al momento (ver abajo) |
| `deploy` | `true` | `false` donde la app llega por sindicación: sin Job |
| `scriptApp.name` | `europesip-hello-dx` | Nombre del contenido en WCM: la clave que convierte un push en actualización. No lo cambies tras la primera instalación |
| `scriptApp.title` | `Hello DX` | Título que se ve en DX |
| `scriptApp.siteArea` | `Script Application Library/Script Applications/` | Dónde se crea |
| `bundle.image` | `ghcr.io/europesip/hcl-dx-scriptapp-helm/europesip-hello-dx:1.0.0` | La app que se sube |
| `dxclient.image` | `hclcr.io/dx-public/dxclient:v95_CF239_20261103-1404` | DXClient, público en el Harbor de HCL |
| `job.waitForDxSeconds` | `600` | Cuánto esperar a DX antes del push |

Todos en [values.yaml](chart/hcl-dx-scriptapp/values.yaml).

## Usarlo para tu propia Script Application

1. Sustituye [app/](app) por tu aplicación (o crea una con `npx @hcl-software/create-dx-script-app`)
   y deja su compilación en `dist/`.
2. Construye y publica su imagen de bundle con [app/Dockerfile](app/Dockerfile) (el workflow de
   [.github/workflows](.github/workflows) lo hace con cada etiqueta).
3. Instala el chart con tu `scriptApp.name`, `scriptApp.title` y `bundle.image`. Un release por
   Script Application.

El chart es genérico: no tiene nada específico de Hello DX.

## Lo que hemos aprendido (DX Compose CF239)

- **Un push publica al momento.** La app pasa a producción en todas las páginas que la usan, sin
  flujo de trabajo. Para revisar los cambios antes, sube a un proyecto de WCM (`dx.projectContext`).
- **Push o sindicación, por entorno, no los dos.** Si producción recibe el contenido por
  sindicación, pon `deploy: false` allí: hacer también push crea un segundo elemento distinto.
- **WCM guarda cada fichero en un elemento de como máximo 5.000.000 bytes.** Un fichero mayor
  (probamos un bundle de 14 MB) hace que DX rechace el push **y deja un elemento incompleto** en WCM.
  El Job comprueba el tamaño de los ficheros antes de tocar DX y para si alguno pasa de 4,5 MB. Divide
  el bundle (*code splitting*) o sirve los recursos grandes desde DAM.
- **DXClient escribe "Content push was successful" aunque DX rechace el contenido.** Su código de
  salida y la respuesta de DX (`"status":"error"`) sí son correctos: el Job comprueba los dos.
- **Las credenciales no van en la línea de comandos.** DXClient avisa de que sus líneas de comandos
  acaban en los logs del contenedor, así que el Job las escribe en el fichero de configuración de
  DXClient.
- **`undeploy-scriptapplication` necesita el ID del contenido**, no el nombre. El Job escribe el ID.
- **Los certificados autofirmados** necesitan la CA (`dx.caSecret`): DXClient (Node.js) los rechaza.
- **El CSS global rompe el portal.** La plantilla de HCL da estilos a `:root`, `body`, `h1`, `a` y
  `button`; dentro de una página de DX eso cambia el aspecto de todo el tema. Hello DX limita cada
  regla a su propio contenedor.
- **Mismo origen, sin secretos.** La app llama a DX con URLs relativas (`/wps/mycontenthandler/...`):
  el navegador envía la cookie de sesión del usuario y DX aplica sus permisos. La lógica que necesite
  secretos o privilegios va a un servicio de backend, no a la Script Application.
- **Una instancia por página** en Hello DX: se monta en un ID de elemento fijo. Para varias
  instancias en la misma página, usa el token de namespace de DX en el ID.

## Desarrollo local

```bash
cd app
cp .env.example .env.local      # DX_TARGET, y los datos de DXClient para dx-deploy
npm install
npm run dev                      # http://localhost:3000, con DX detrás de un proxy (entra antes en /wps/portal)
npm run build                    # dist/
npm run dx-deploy                # sube dist/ a DX desde tu equipo (script de HCL, DXClient de npm)
```

Node.js 24 o superior.

## Licencia

Apache License 2.0 ([LICENSE](LICENSE), [NOTICE](NOTICE)). La app parte de la plantilla
`create-dx-script-app` de HCL (Apache-2.0, HCL America Inc.); `app/deploy.cjs` es el fichero de HCL
sin cambios. DXClient es software de HCL con su propia licencia, que se usa desde la imagen pública
de HCL y no se redistribuye aquí. HCL, Digital Experience y otros nombres de producto son marcas de
sus respectivos propietarios.
