#!/bin/sh
# Pushes the Script Applications of the bundle in $APP_DIR to HCL DX with DXClient.
# Runs inside the HCL DXClient image (/dxclient). Exits non-zero on any failure, so the Job fails.
#
# Apps: APPS_JSON (chart value "apps": several apps, each one in a folder of the bundle) or, if it is
# empty, the single app of APP_NAME / APP_TITLE / APP_SITE_AREA / APP_MAIN_HTML (whole bundle).
# Then, if AFTER_PUSH is set, runs that script with APP_IDS_FILE ("<name><TAB><content ID>" lines).
set -eu
cd /dxclient
log() { echo "$(date -u +%H:%M:%S) $*"; }
fail() { log "ERROR: $*"; exit 1; }

# 1. License: the chart only renders this Job when dxclient.acceptLicense=true
[ "${ACCEPT_LICENSE:-}" = "true" ] || fail "the DXClient license has not been accepted (dxclient.acceptLicense)"
./bin/dxclient accept-license >/dev/null 2>&1 || true

# 2. The list of apps, one per line: name<TAB>title<TAB>folder<TAB>main HTML<TAB>site area
#    (no field may be empty: "read" merges consecutive tabs)
APPS=/tmp/apps.tsv
if [ -n "${APPS_JSON:-}" ]; then
  node -e '
    for (const a of JSON.parse(process.env.APPS_JSON)) {
      const f = [a.name, a.title, a.path, a.mainHtmlFile, a.siteArea];
      if (f.some(v => typeof v !== "string" || /[\t\n]/.test(v))) throw new Error("bad app entry: " + JSON.stringify(a));
      if (a.path.split("/").includes("..")) throw new Error("app path outside the bundle: " + a.path);
      console.log(f.join("\t"));
    }' > "$APPS" || fail "APPS_JSON is not valid"
else
  printf '%s\t%s\t%s\t%s\t%s\n' "$APP_NAME" "$APP_TITLE" . "$APP_MAIN_HTML" "$APP_SITE_AREA" > "$APPS"   # "." = the whole bundle
fi

# 3. Check every app before touching DX. WCM stores each file in one element, limited to 5,000,000
#    bytes as stored: a bigger file makes the push fail half way and leaves an incomplete item.
TAB=$(printf '\t')
appdir() { if [ "$1" = . ]; then echo "$APP_DIR"; else echo "$APP_DIR/$1"; fi; }
while IFS="$TAB" read -r name title dir main area; do
  d=$(appdir "$dir")
  [ -f "$d/$main" ] || fail "$name: main HTML file $main not found in the bundle ($d)"
  big=$(find "$d" -type f -size +4500k)
  [ -z "$big" ] || fail "$name: files over 4.5 MB, WCM cannot store them (split the bundle or serve them from DAM): $big"
  log "app $name: $(find "$d" -type f | wc -l) files, $(du -sh "$d" | cut -f1)"
done < "$APPS"

# 4. Connection settings and credentials go to DXClient's config file, not to the command line
#    (DXClient warns that its command lines end up in the container logs).
node -e '
  const fs = require("fs"), e = process.env, f = "dist/configuration/config.json";
  const c = JSON.parse(fs.readFileSync(f, "utf8"));
  Object.assign(c, { dxProtocol: e.DX_PROTOCOL, hostname: e.DX_HOST, dxPort: e.DX_PORT,
    dxUsername: e.DX_USERNAME, dxPassword: e.DX_PASSWORD, contenthandlerPath: e.DX_CONTENT_HANDLER_PATH,
    virtualPortalContext: e.DX_VIRTUAL_PORTAL_CONTEXT, projectContext: e.DX_PROJECT_CONTEXT });
  fs.mkdirSync("store", { recursive: true });
  fs.writeFileSync("store/config.json", JSON.stringify(c, null, 2), { mode: 0o600 });'

# 5. Wait for DX (on a first install it may still be starting)
url="$DX_PROTOCOL://$DX_HOST:$DX_PORT/wps/portal"
log "waiting for $url (max ${WAIT_FOR_DX_SECONDS}s)"
end=$(( $(date +%s) + WAIT_FOR_DX_SECONDS ))
until node -e 'fetch(process.argv[1], { redirect: "manual" }).then(r => process.exit(r.status < 500 ? 0 : 1),
                 e => { console.error("  " + (e.cause?.code || e.message)); process.exit(1) })' "$url"; do
  [ "$(date +%s)" -lt "$end" ] || fail "DX did not answer at $url (for a self-signed certificate set dx.caSecret)"
  sleep 10
done

# 6. Push: creates each app the first time, updates the same WCM item afterwards
# DX may answer /wps/portal while WCM is still starting (seen right after a "helm upgrade" of DX:
# "Service Unavailable"). Those temporary errors are retried; any other error fails at once.
push() {  # push <name> <title> <folder> <main HTML> <site area>
  log "pushing '$1' to $5"
  attempt=1
  while :; do
    rc=0
    ./bin/dxclient deploy-scriptapplication push \
      -wcmSiteArea "$5" -wcmContentName "$1" -wcmContentTitle "$2" \
      -contentRoot "$3" -mainHtmlFile "$4" > /tmp/push.log 2>&1 || rc=$?
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
    fail "push of '$1' failed (exit $rc). If DX created an incomplete item, remove it with dxclient undeploy-scriptapplication --wcmContentId <id>"
  fi
  id=$(sed -n 's/.*"contentId":"\([^"]*\)".*/\1/p' /tmp/push.log | head -1)
  # The after-push script needs the IDs; without it, a missing ID is only logged (as in chart 0.1.x)
  [ -n "$id" ] || [ -z "${AFTER_PUSH:-}" ] || fail "DX did not return the content ID of '$1'"
  printf '%s\t%s\n' "$1" "$id" >> "$APP_IDS_FILE"
  log "OK: '$1' is in WCM (content ID $id)"
}
export APP_IDS_FILE=/tmp/app-ids.tsv
: > "$APP_IDS_FILE"
while IFS="$TAB" read -r name title dir main area; do
  push "$name" "$title" "$(appdir "$dir")" "$main" "$area" < /dev/null
done < "$APPS"

# 7. Optional script after all the pushes (e.g. pages with XMLAccess), with DXClient configured
if [ -n "${AFTER_PUSH:-}" ]; then
  log "after-push script $AFTER_PUSH"
  sh "$AFTER_PUSH" || fail "the after-push script failed"
  log "after-push script finished"
fi
