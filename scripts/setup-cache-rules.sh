#!/usr/bin/env bash
# Configures Cloudflare caching for steepworksai.com:
#   1. Enables Cloudflare proxy (orange cloud) on the main A records
#   2. Sets SSL mode to "Full" so HTTPS keeps working through the proxy
#   3. Creates a Cache Rule: bypass Cloudflare + browser cache for HTML
#   4. Purges everything currently cached
#
# Run once. Re-run anytime you want to force a full cache purge.
#
# Usage:
#   bash scripts/setup-cache-rules.sh
#
# Requires .env.local with CF_TOKEN that has:
#   - Zone > DNS > Edit
#   - Zone > Cache Rules > Edit
#   - Zone > Cache Purge > Purge

set -euo pipefail

DOMAIN="steepworksai.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env.local"

[[ ! -f "$ENV_FILE" ]] && { echo "Error: .env.local not found at $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${CF_TOKEN:?CF_TOKEN not set in .env.local}"

AUTH=(-H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json")

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│  Setting up Cloudflare caching for $DOMAIN"
echo "└─────────────────────────────────────────────────────┘"
echo ""

# ── Get Zone ID ────────────────────────────────────────────────────────────────

ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" "${AUTH[@]}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['result'][0]['id'])")
echo "Zone ID: $ZONE_ID"
echo ""

CF_API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID"

# ── Step 1: Enable proxy on main A records ─────────────────────────────────────

echo "── [1/4] Enabling Cloudflare proxy on $DOMAIN A records..."
RECORD_IDS=$(curl -s "$CF_API/dns_records?type=A&name=$DOMAIN" "${AUTH[@]}" \
  | python3 -c "import sys,json; [print(r['id']+'|'+r['content']) for r in json.load(sys.stdin)['result']]")

while IFS='|' read -r id ip; do
  curl -s -X PATCH "$CF_API/dns_records/$id" "${AUTH[@]}" \
    -d '{"proxied":true}' \
    | python3 -c "
import sys,json; r=json.load(sys.stdin)
print('   ✓ proxy ON  A -> $ip' if r.get('success') else '   ✗ failed: '+str(r.get('errors')))
"
done <<< "$RECORD_IDS"

# Also proxy www CNAME if it exists
WWW_ID=$(curl -s "$CF_API/dns_records?type=CNAME&name=www.$DOMAIN" "${AUTH[@]}" \
  | python3 -c "
import sys,json
recs = json.load(sys.stdin).get('result',[])
print(recs[0]['id'] if recs else '')
")
if [[ -n "$WWW_ID" ]]; then
  curl -s -X PATCH "$CF_API/dns_records/$WWW_ID" "${AUTH[@]}" \
    -d '{"proxied":true}' \
    | python3 -c "
import sys,json; r=json.load(sys.stdin)
print('   ✓ proxy ON  CNAME www -> steepworksai.github.io' if r.get('success') else '   ✗ failed: '+str(r.get('errors')))
"
fi
echo ""

# ── Step 2: Set SSL mode to Full ───────────────────────────────────────────────

echo "── [2/4] Setting SSL mode to Full (Cloudflare ↔ GitHub Pages over HTTPS)..."
curl -s -X PATCH "$CF_API/settings/ssl" "${AUTH[@]}" \
  -d '{"value":"full"}' \
  | python3 -c "
import sys,json; r=json.load(sys.stdin)
print('   ✓ SSL mode: Full' if r.get('success') else '   ✗ failed: '+str(r.get('errors')))
"
echo ""

# ── Step 3: Create Cache Rule — bypass cache for HTML ─────────────────────────

echo "── [3/4] Creating Cache Rule (bypass HTML cache)..."

# Check if a cache settings ruleset already exists for this zone
EXISTING_RULESET_ID=$(curl -s "$CF_API/rulesets" "${AUTH[@]}" \
  | python3 -c "
import sys,json
for r in json.load(sys.stdin).get('result',[]):
    if r.get('phase') == 'http_request_cache_settings' and r.get('kind') == 'zone':
        print(r['id']); break
" 2>/dev/null || echo "")

# Expression: all requests to the main domain and www
EXPRESSION='(http.host eq "steepworksai.com") or (http.host eq "www.steepworksai.com")'

RULESET_PAYLOAD=$(python3 -c "
import json
payload = {
  'name': 'Cache Rules — steepworksai.com',
  'description': 'Bypass Cloudflare and browser cache for HTML — always serve fresh pages',
  'kind': 'zone',
  'phase': 'http_request_cache_settings',
  'rules': [
    {
      'action': 'set_cache_settings',
      'action_parameters': {
        'cache': False,
        'browser_ttl': {
          'mode': 'bypass'
        }
      },
      'expression': '(http.host eq \"steepworksai.com\") or (http.host eq \"www.steepworksai.com\")',
      'description': 'Bypass cache for all HTML — always serve fresh pages',
      'enabled': True
    }
  ]
}
print(json.dumps(payload))
")

if [[ -n "$EXISTING_RULESET_ID" ]]; then
  curl -s -X PUT "$CF_API/rulesets/$EXISTING_RULESET_ID" "${AUTH[@]}" \
    -d "$RULESET_PAYLOAD" \
    | python3 -c "
import sys,json; r=json.load(sys.stdin)
print('   ✓ Updated existing Cache Rule ruleset' if r.get('success') else '   ✗ Failed: '+str(r.get('errors')))
"
else
  curl -s -X POST "$CF_API/rulesets" "${AUTH[@]}" \
    -d "$RULESET_PAYLOAD" \
    | python3 -c "
import sys,json; r=json.load(sys.stdin)
print('   ✓ Created Cache Rule ruleset' if r.get('success') else '   ✗ Failed: '+str(r.get('errors')))
"
fi
echo ""

# ── Step 4: Purge everything ───────────────────────────────────────────────────

echo "── [4/4] Purging all cached content..."
curl -s -X POST "$CF_API/purge_cache" "${AUTH[@]}" \
  -d '{"purge_everything":true}' \
  | python3 -c "
import sys,json; r=json.load(sys.stdin)
print('   ✓ Cache purged successfully' if r.get('success') else '   ✗ Failed: '+str(r.get('errors')))
"
echo ""

echo "✓ All done!"
echo ""
echo "  steepworksai.com is now proxied through Cloudflare."
echo "  HTML pages bypass both Cloudflare cache and browser cache."
echo "  Users will always get the latest version on every visit."
echo ""
echo "Note: If you ever push an update and want to force a fresh cache purge,"
echo "just re-run this script — step 4 alone is safe to run repeatedly."
