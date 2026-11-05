#!/bin/sh
# Pushes the Script Application in $APP_DIR to HCL DX with DXClient.
# Runs inside the HCL DXClient image (/dxclient). Exits non-zero on any failure, so the Job fails.
set -eu
cd /dxclient
log() { echo "$(date -u +%H:%M:%S) $*"; }
fail() { log "ERROR: $*"; exit 1; }

# 1. License: the chart only renders this Job when dxclient.acceptLicense=true
[ "${ACCEPT_LICENSE:-}" = "true" ] || fail "the DXClient license has not been accepted (dxclient.acceptLicense)"
./bin/dxclient accept-license >/dev/null 2>&1 || true

# 2. Check the app before touching DX. WCM stores each file in one element, limited to 5,000,000
#    bytes as stored: a bigger file makes the push fail half way and leaves an incomplete item.
[ -f "$APP_DIR/$APP_MAIN_HTML" ] || fail "main HTML file $APP_MAIN_HTML not found in the bundle ($APP_DIR)"
big=$(find "$APP_DIR" -type f -size +4500k)
[ -z "$big" ] || fail "files over 4.5 MB, WCM cannot store them (split the bundle or serve them from DAM): $big"
log "app: $(find "$APP_DIR" -type f | wc -l) files, $(du -sh "$APP_DIR" | cut -f1)"

# 3. Connection settings and credentials go to DXClient's config file, not to the command line
#    (DXClient warns that its command lines end up in the container logs).
node -e '
  const fs = require("fs"), e = process.env, f = "dist/configuration/config.json";
  const c = JSON.parse(fs.readFileSync(f, "utf8"));
  Object.assign(c, { dxProtocol: e.DX_PROTOCOL, hostname: e.DX_HOST, dxPort: e.DX_PORT,
    dxUsername: e.DX_USERNAME, dxPassword: e.DX_PASSWORD, contenthandlerPath: e.DX_CONTENT_HANDLER_PATH,
    virtualPortalContext: e.DX_VIRTUAL_PORTAL_CONTEXT, projectContext: e.DX_PROJECT_CONTEXT });
  fs.mkdirSync("store", { recursive: true });
  fs.writeFileSync("store/config.json", JSON.stringify(c, null, 2), { mode: 0o600 });'

# 4. Wait for DX (on a first install it may still be starting)
url="$DX_PROTOCOL://$DX_HOST:$DX_PORT/wps/portal"
log "waiting for $url (max ${WAIT_FOR_DX_SECONDS}s)"
end=$(( $(date +%s) + WAIT_FOR_DX_SECONDS ))
until node -e 'fetch(process.argv[1], { redirect: "manual" }).then(r => process.exit(r.status < 500 ? 0 : 1),
                 e => { console.error("  " + (e.cause?.code || e.message)); process.exit(1) })' "$url"; do
  [ "$(date +%s)" -lt "$end" ] || fail "DX did not answer at $url (for a self-signed certificate set dx.caSecret)"
  sleep 10
done

# 5. Push: creates the app the first time, updates the same WCM item afterwards
# DX may answer /wps/portal while WCM is still starting (seen right after a "helm upgrade" of DX:
# "Service Unavailable"). Those temporary errors are retried; any other error fails at once.
log "pushing '$APP_NAME' to $APP_SITE_AREA"
attempt=1
while :; do
  rc=0
  ./bin/dxclient deploy-scriptapplication push \
    -wcmSiteArea "$APP_SITE_AREA" -wcmContentName "$APP_NAME" -wcmContentTitle "$APP_TITLE" \
    -contentRoot "$APP_DIR" -mainHtmlFile "$APP_MAIN_HTML" > /tmp/push.log 2>&1 || rc=$?
  cat /tmp/push.log
  if [ "$rc" -ne 0 ] && [ "$attempt" -lt "${PUSH_ATTEMPTS:-5}" ] \
     && grep -qiE "Service Unavailable|Bad Gateway|Gateway Timeout|ECONNRESET|ECONNREFUSED|socket hang up" /tmp/push.log; then
    log "DX is not ready yet (attempt $attempt): retrying in 20 s"
    attempt=$((attempt + 1)); sleep 20; continue
  fi
  break
done
# DXClient prints "Content push was successful" even when DX rejects the content: trust the exit
# code and the "status" of DX's answer, not that line.
if [ "$rc" -ne 0 ] || ! grep -q '"status":"success"' /tmp/push.log; then
  fail "push failed (exit $rc). If DX created an incomplete item, remove it with dxclient undeploy-scriptapplication --wcmContentId <id>"
fi
id=$(sed -n 's/.*"contentId":"\([^"]*\)".*/\1/p' /tmp/push.log | head -1)
log "OK: '$APP_NAME' is in WCM (content ID $id)"
