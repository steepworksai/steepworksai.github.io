#!/usr/bin/env bash
set -euo pipefail

DOMAIN="steepworksai.com"

# Load token from .env.local (one level up from scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env.local not found at $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${CF_TOKEN:?CF_TOKEN not set in .env.local}"

AUTH=(-H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json")

echo "── Looking up Zone ID for $DOMAIN..."
ZONE_RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" "${AUTH[@]}")
CF_ZONE_ID=$(echo "$ZONE_RESP" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not data.get('success') or not data.get('result'):
    print('ERROR: ' + str(data.get('errors', 'no zones found')), file=sys.stderr)
    sys.exit(1)
print(data['result'][0]['id'])
")
echo "   Zone ID: $CF_ZONE_ID"

API="https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records"

GITHUB_PAGES_IPS=(
  "185.199.108.153"
  "185.199.109.153"
  "185.199.110.153"
  "185.199.111.153"
)

echo "── Fetching existing A records for $DOMAIN..."
EXISTING=$(curl -s -X GET "$API?type=A&name=$DOMAIN" "${AUTH[@]}")
IDS=$(echo "$EXISTING" | python3 -c "
import sys, json
records = json.load(sys.stdin).get('result', [])
for r in records:
    print(r['id'])
")

if [[ -n "$IDS" ]]; then
  echo "── Deleting existing A records..."
  while IFS= read -r id; do
    curl -s -X DELETE "$API/$id" "${AUTH[@]}" | python3 -c "
import sys, json; r = json.load(sys.stdin)
print('  deleted' if r.get('success') else '  failed: ' + str(r.get('errors')))
"
  done <<< "$IDS"
else
  echo "── No existing A records found."
fi

echo "── Adding GitHub Pages A records (proxy off)..."
for ip in "${GITHUB_PAGES_IPS[@]}"; do
  curl -s -X POST "$API" "${AUTH[@]}" \
    -d "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}" \
    | python3 -c "
import sys, json; r = json.load(sys.stdin)
if r.get('success'):
    print('  added A -> $ip')
else:
    print('  failed: ' + str(r.get('errors')))
"
done

echo "── Handling www CNAME..."
EXISTING_WWW=$(curl -s -X GET "$API?type=CNAME&name=www.$DOMAIN" "${AUTH[@]}")
WWW_ID=$(echo "$EXISTING_WWW" | python3 -c "
import sys, json
records = json.load(sys.stdin).get('result', [])
print(records[0]['id'] if records else '')
")

CNAME_PAYLOAD="{\"type\":\"CNAME\",\"name\":\"www\",\"content\":\"steepworksai.github.io\",\"ttl\":1,\"proxied\":false}"

if [[ -n "$WWW_ID" ]]; then
  curl -s -X PUT "$API/$WWW_ID" "${AUTH[@]}" -d "$CNAME_PAYLOAD" \
    | python3 -c "
import sys, json; r = json.load(sys.stdin)
print('  updated www CNAME -> steepworksai.github.io' if r.get('success') else '  failed: ' + str(r.get('errors')))
"
else
  curl -s -X POST "$API" "${AUTH[@]}" -d "$CNAME_PAYLOAD" \
    | python3 -c "
import sys, json; r = json.load(sys.stdin)
print('  added www CNAME -> steepworksai.github.io' if r.get('success') else '  failed: ' + str(r.get('errors')))
"
fi

echo ""
echo "Done. DNS propagation typically takes 1–5 minutes."
echo "Then in GitHub Pages settings, 'Enforce HTTPS' should become available."
