#!/usr/bin/env bash
# Register an Android app's SHA-1 / SHA-256 certificate fingerprints on the
# matching Firebase Android app. Two modes:
#
#   A) Direct values (recommended for Play App Signing) — paste the SHA-1 /
#      SHA-256 shown in Play Console -> Setup -> App signing (the *app signing
#      key*, which is what installed release builds are signed with):
#        scripts/register-android-sha.sh --project peppercheck-474211 \
#            --package dev.cloveclove.peppercheck \
#            --sha1 AA:BB:.. --sha256 11:22:..
#
#   B) Local keystore (debug / local upload keys) — extracts fingerprints via
#      keytool (only the public fingerprint is read; private material is never
#      printed):
#        scripts/register-android-sha.sh --project peppercheck-dev \
#            --package dev.cloveclove.peppercheck.dev \
#            --keystore ~/.config/.android/debug.keystore \
#            --alias androiddebugkey --storepass android
#      (or just: scripts/register-android-sha.sh --dev)
#
# Idempotent: skips any fingerprint already registered. Add --dry-run to preview.
# Requires: gcloud (authenticated owner/editor), python3, curl; keytool only for mode B.
set -euo pipefail

PROJECT="" PACKAGE="" KEYSTORE="" ALIAS="" STOREPASS="" KEYPASS=""
SHA1_IN="" SHA256_IN="" DRYRUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dev)
      PROJECT="peppercheck-dev"; ALIAS="androiddebugkey"
      STOREPASS="android"; KEYPASS="android"
      PACKAGE="dev.cloveclove.peppercheck.dev"
      for c in "$HOME/.config/.android/debug.keystore" "$HOME/.android/debug.keystore"; do
        [ -f "$c" ] && KEYSTORE="$c" && break
      done ;;
    --project)   PROJECT="$2"; shift ;;
    --package)   PACKAGE="$2"; shift ;;
    --keystore)  KEYSTORE="$2"; shift ;;
    --alias)     ALIAS="$2"; shift ;;
    --storepass) STOREPASS="$2"; shift ;;
    --keypass)   KEYPASS="$2"; shift ;;
    --sha1)      SHA1_IN="$2"; shift ;;
    --sha256)    SHA256_IN="$2"; shift ;;
    --dry-run)   DRYRUN=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -n "$PROJECT" ] || { echo "missing --project"; exit 2; }
command -v gcloud >/dev/null || { echo "need gcloud"; exit 1; }
command -v python3 >/dev/null || { echo "need python3"; exit 1; }

norm() { echo "$1" | tr -d ': ' | tr 'A-F' 'a-f'; }

SHA1="" SHA256=""
if [ -n "$KEYSTORE" ]; then
  [ -f "$KEYSTORE" ] || { echo "keystore not found: $KEYSTORE"; exit 2; }
  command -v keytool >/dev/null || { echo "need keytool (JDK) for keystore mode"; exit 1; }
  out="$(keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" \
    -storepass "$STOREPASS" ${KEYPASS:+-keypass "$KEYPASS"} 2>/dev/null)" \
    || { echo "keytool failed (wrong alias/password?)"; exit 1; }
  SHA1="$(norm "$(echo "$out"  | grep -i 'SHA1:'   | head -1 | sed 's/.*SHA1: *//')")"
  SHA256="$(norm "$(echo "$out" | grep -i 'SHA256:' | head -1 | sed 's/.*SHA256: *//')")"
fi
[ -n "$SHA1_IN" ]   && SHA1="$(norm "$SHA1_IN")"
[ -n "$SHA256_IN" ] && SHA256="$(norm "$SHA256_IN")"

# Validate lengths (SHA-1 = 40 hex, SHA-256 = 64 hex).
[ -z "$SHA1" ]   || [ "${#SHA1}" -eq 40 ]  || { echo "SHA-1 must be 40 hex chars (got ${#SHA1})"; exit 2; }
[ -z "$SHA256" ] || [ "${#SHA256}" -eq 64 ] || { echo "SHA-256 must be 64 hex chars (got ${#SHA256})"; exit 2; }
[ -n "$SHA1$SHA256" ] || { echo "nothing to register (give --keystore, --sha1 and/or --sha256)"; exit 2; }
[ -z "$SHA1" ]   || echo "SHA-1  : $SHA1"
[ -z "$SHA256" ] || echo "SHA-256: $SHA256"

TOKEN="$(gcloud auth print-access-token 2>/dev/null)" || { echo "run: gcloud auth login"; exit 1; }
API="https://firebase.googleapis.com/v1beta1/projects/$PROJECT"
hdr=(-H "Authorization: Bearer $TOKEN" -H "X-Goog-User-Project: $PROJECT")

APP_JSON="$(curl -sS "${hdr[@]}" "$API/androidApps")"
APPID="$(PKG="$PACKAGE" python3 -c '
import sys,json,os
apps=json.load(sys.stdin).get("apps",[]) or []; pkg=os.environ.get("PKG","")
m=[a for a in apps if (not pkg or a.get("packageName")==pkg)]
print(m[0]["appId"] if m else "")' <<<"$APP_JSON")"
[ -n "$APPID" ] || { echo "no Android app matched in $PROJECT (package='$PACKAGE')"; echo "$APP_JSON" | head -c 400; exit 1; }
echo "Android app: $APPID  (package: ${PACKAGE:-<first>})"

EXIST="$(curl -sS "${hdr[@]}" "$API/androidApps/$APPID/sha")"
have_sha() { HAVE="$EXIST" WANT="$1" python3 -c '
import sys,json,os
have=[c.get("shaHash","").lower() for c in json.loads(os.environ["HAVE"]).get("certificates",[]) or []]
sys.exit(0 if os.environ["WANT"] in have else 1)'; }

register() { # $1=hash $2=certType
  if have_sha "$1"; then echo "[OK] $2 already registered — skip"; return; fi
  if [ "$DRYRUN" -eq 1 ]; then echo "[dry-run] would POST $2 $1"; return; fi
  local resp code
  resp="$(curl -sS -w '\n%{http_code}' "${hdr[@]}" -H 'Content-Type: application/json' \
    -X POST "$API/androidApps/$APPID/sha" -d "{\"shaHash\":\"$1\",\"certType\":\"$2\"}")"
  code="$(echo "$resp" | tail -1)"
  if [ "$code" = "200" ]; then echo "[OK] registered $2"; else
    echo "[FAIL] $2 HTTP $code"; echo "$resp" | sed '$d' | head -c 400; return 1; fi
}

[ -z "$SHA1" ]   || register "$SHA1" SHA_1
[ -z "$SHA256" ] || register "$SHA256" SHA_256
echo "Done for $PROJECT."
