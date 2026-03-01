#!/usr/bin/env bash
# Onboards a new SteepWorksAI product repo to its own subdomain, end-to-end:
#   1. Creates a minimal docs/index.html in the repo (if absent)
#   2. Writes CNAME file into the repo (via GitHub API — no clone needed)
#   3. Adds/updates Cloudflare DNS CNAME  (proxy off)
#   4. Enables GitHub Pages on the repo
#   5. Sets the custom domain on GitHub Pages
#   6. Polls until TLS cert is issued
#   7. Enforces HTTPS
#
# Usage:
#   bash scripts/add-product.sh <subdomain> <gh-repo> [product-name] [pages-branch] [pages-path]
#
# Examples:
#   bash scripts/add-product.sh briefer   steepworksai/Briefer   "Briefer"   main /docs
#   bash scripts/add-product.sh formbuddy steepworksai/FormBuddy "FormBuddy" main /docs
#   bash scripts/add-product.sh analytics steepworksai/Analytics "Analytics" main /
#
# Requires:
#   - .env.local with CF_TOKEN  (Cloudflare token — "Edit zone DNS" permission)
#   - gh CLI authenticated       (gh auth login)

set -euo pipefail

# ── Args ─────────────────────────────────────────────────────────────────────

SUBDOMAIN="${1:?Usage: $0 <subdomain> <gh-repo> [product-name] [pages-branch] [pages-path]}"
GH_REPO="${2:?Usage: $0 <subdomain> <gh-repo> [product-name] [pages-branch] [pages-path]}"
PRODUCT_NAME="${3:-}"   # human-readable name e.g. "Briefer"; defaults to Title-cased subdomain
PAGES_BRANCH="${4:-main}"
PAGES_PATH="${5:-/docs}"

# Default product name to title-cased subdomain if not provided
if [[ -z "$PRODUCT_NAME" ]]; then
  PRODUCT_NAME="$(echo "${SUBDOMAIN:0:1}" | tr '[:lower:]' '[:upper:]')${SUBDOMAIN:1}"
fi

DOMAIN="steepworksai.com"
FQDN="$SUBDOMAIN.$DOMAIN"

# Derive the CNAME file path inside the repo from the pages source path
# e.g. /docs -> docs/CNAME   /  -> CNAME
if [[ "$PAGES_PATH" == "/" ]]; then
  CNAME_REPO_PATH="CNAME"
else
  CNAME_REPO_PATH="${PAGES_PATH#/}/CNAME"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: .env.local not found at $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"
: "${CF_TOKEN:?CF_TOKEN not set in .env.local}"

CF_AUTH=(-H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json")

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│  Adding product: $PRODUCT_NAME"
echo "│  URL:            https://$FQDN"
echo "│  Repo:           $GH_REPO  ($PAGES_BRANCH$PAGES_PATH)"
echo "└─────────────────────────────────────────────────────┘"
echo ""

# ── Step 0: MIT License ───────────────────────────────────────────────────────

echo "── [0/6] Adding MIT License..."
bash "$SCRIPT_DIR/add-license.sh" "$GH_REPO"

# ── Step 1: Create minimal docs/index.html if absent ─────────────────────────

if [[ "$PAGES_PATH" == "/" ]]; then
  INDEX_REPO_PATH="index.html"
else
  INDEX_REPO_PATH="${PAGES_PATH#/}/index.html"
fi

echo "── [1/7] Checking for $INDEX_REPO_PATH in $GH_REPO..."

EXISTING_INDEX=$(gh api "repos/$GH_REPO/contents/$INDEX_REPO_PATH" 2>/dev/null || echo "")

if [[ -n "$EXISTING_INDEX" ]]; then
  echo "   index.html already exists — skipping."
else
  # Build a minimal branded placeholder page
  INDEX_CONTENT=$(cat <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${PRODUCT_NAME} — SteepWorksAI</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: system-ui, -apple-system, sans-serif;
      background: #f9fafb; color: #111827;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      min-height: 100vh; text-align: center; padding: 24px;
    }
    .dot {
      width: 48px; height: 48px;
      background: linear-gradient(135deg, #6366f1, #8b5cf6);
      border-radius: 14px; margin: 0 auto 24px;
    }
    h1 { font-size: 36px; font-weight: 900; letter-spacing: -1px; color: #1f2937; }
    h1 span { color: #6366f1; }
    p { margin-top: 16px; font-size: 17px; color: #6b7280; max-width: 420px; line-height: 1.6; }
    .back { margin-top: 32px; font-size: 14px; color: #9ca3af; }
    .back a { color: #6366f1; text-decoration: none; font-weight: 600; }
  </style>
</head>
<body>
  <div class="dot"></div>
  <h1><span>${PRODUCT_NAME}</span></h1>
  <p>This page is coming soon. Check back shortly.</p>
  <p class="back">A product by <a href="https://steepworksai.com">SteepWorksAI</a></p>
</body>
</html>
HTML
)

  ENCODED_INDEX=$(printf '%s' "$INDEX_CONTENT" | base64)

  gh api "repos/$GH_REPO/contents/$INDEX_REPO_PATH" \
    --method PUT \
    --field message="Add minimal docs/index.html placeholder for $FQDN" \
    --field content="$ENCODED_INDEX" \
    --silent
  echo "   Created $INDEX_REPO_PATH (placeholder page)."
fi

# ── Step 2: Write CNAME file into the repo ────────────────────────────────────

echo "── [2/7] Writing $CNAME_REPO_PATH to $GH_REPO..."

ENCODED=$(printf '%s' "$FQDN" | base64)

EXISTING_FILE=$(gh api "repos/$GH_REPO/contents/$CNAME_REPO_PATH" 2>/dev/null || echo "")

if [[ -n "$EXISTING_FILE" ]]; then
  CURRENT=$(echo "$EXISTING_FILE" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
print(base64.b64decode(data['content'].replace('\\n','')).decode().strip())
")
  if [[ "$CURRENT" == "$FQDN" ]]; then
    echo "   CNAME file already correct — skipping."
  else
    SHA=$(echo "$EXISTING_FILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
    gh api "repos/$GH_REPO/contents/$CNAME_REPO_PATH" \
      --method PUT \
      --field message="Update CNAME to $FQDN" \
      --field content="$ENCODED" \
      --field sha="$SHA" \
      --silent
    echo "   Updated CNAME file: $CURRENT -> $FQDN"
  fi
else
  gh api "repos/$GH_REPO/contents/$CNAME_REPO_PATH" \
    --method PUT \
    --field message="Add CNAME for $FQDN" \
    --field content="$ENCODED" \
    --silent
  echo "   Created CNAME file: $FQDN"
fi

# ── Step 3: Cloudflare DNS CNAME ──────────────────────────────────────────────

echo "── [3/7] Configuring Cloudflare DNS for $FQDN..."

ZONE_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" "${CF_AUTH[@]}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not data.get('success') or not data.get('result'):
    print('ERROR: ' + str(data.get('errors')), file=sys.stderr); sys.exit(1)
print(data['result'][0]['id'])
")

CF_API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
CNAME_PAYLOAD="{\"type\":\"CNAME\",\"name\":\"$SUBDOMAIN\",\"content\":\"steepworksai.github.io\",\"ttl\":1,\"proxied\":false}"

EXISTING_ID=$(curl -s "$CF_API?type=CNAME&name=$FQDN" "${CF_AUTH[@]}" \
  | python3 -c "
import sys, json
records = json.load(sys.stdin).get('result', [])
print(records[0]['id'] if records else '')
")

if [[ -n "$EXISTING_ID" ]]; then
  curl -s -X PUT "$CF_API/$EXISTING_ID" "${CF_AUTH[@]}" -d "$CNAME_PAYLOAD" \
    | python3 -c "
import sys, json; r = json.load(sys.stdin)
print('   Updated: $FQDN -> steepworksai.github.io' if r.get('success') else '   Failed: ' + str(r.get('errors')))
"
else
  curl -s -X POST "$CF_API" "${CF_AUTH[@]}" -d "$CNAME_PAYLOAD" \
    | python3 -c "
import sys, json; r = json.load(sys.stdin)
print('   Added:   $FQDN -> steepworksai.github.io' if r.get('success') else '   Failed: ' + str(r.get('errors')))
"
fi

# ── Step 4: Enable GitHub Pages ───────────────────────────────────────────────

echo "── [4/7] Enabling GitHub Pages on $GH_REPO..."

PAGES_STATUS=$(gh api "repos/$GH_REPO/pages" 2>&1 || true)

if echo "$PAGES_STATUS" | grep -q '"html_url"'; then
  echo "   Pages already enabled — ensuring custom domain is set..."
  CURRENT_CNAME=$(echo "$PAGES_STATUS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cname',''))" 2>/dev/null || echo "")
  if [[ "$CURRENT_CNAME" != "$FQDN" ]]; then
    gh api "repos/$GH_REPO/pages" --method PUT --field cname="$FQDN" --silent
    echo "   Custom domain updated: $CURRENT_CNAME -> $FQDN"
  else
    echo "   Custom domain already set to $FQDN"
  fi
else
  gh api "repos/$GH_REPO/pages" --method POST \
    --field "source[branch]=$PAGES_BRANCH" \
    --field "source[path]=$PAGES_PATH" \
    --silent
  echo "   Pages enabled ($PAGES_BRANCH$PAGES_PATH)."

  # Set custom domain (Pages API needs a separate PUT after creation)
  sleep 2
  gh api "repos/$GH_REPO/pages" --method PUT --field cname="$FQDN" --silent
  echo "   Custom domain set: $FQDN"
fi

# ── Step 5: Poll for TLS cert ─────────────────────────────────────────────────

echo "── [5/7] Waiting for TLS certificate..."
MAX_WAIT=180
ELAPSED=0
INTERVAL=10

while [[ $ELAPSED -lt $MAX_WAIT ]]; do
  CERT_STATE=$(gh api "repos/$GH_REPO/pages" --jq '.https_certificate.state' 2>/dev/null || echo "unknown")
  if [[ "$CERT_STATE" == "approved" ]]; then
    echo "   Certificate issued."
    break
  fi
  printf "   [%3ds] cert state: %s ...\r" "$ELAPSED" "$CERT_STATE"
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done
echo ""

if [[ "$CERT_STATE" != "approved" ]]; then
  echo "   Warning: cert not ready after ${MAX_WAIT}s."
  echo "   Run this manually once it's issued:"
  echo "   gh api repos/$GH_REPO/pages --method PUT --field https_enforced=true"
  exit 0
fi

# ── Step 6: Enforce HTTPS ─────────────────────────────────────────────────────

echo "── [6/7] Enforcing HTTPS..."
gh api "repos/$GH_REPO/pages" --method PUT --field https_enforced=true --silent
echo "   HTTPS enforced."

echo ""
echo "✓ All done! Live at: https://$FQDN"
