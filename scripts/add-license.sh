#!/usr/bin/env bash
# Adds an MIT License file to any steepworksai GitHub repo via the API.
# Skips silently if the file already exists and is correct.
#
# Usage:
#   bash scripts/add-license.sh <gh-repo>
#
# Examples:
#   bash scripts/add-license.sh steepworksai/Briefer
#   bash scripts/add-license.sh steepworksai/FormBuddy
#   bash scripts/add-license.sh steepworksai/NewTool

set -euo pipefail

GH_REPO="${1:?Usage: $0 <gh-repo>  e.g. steepworksai/NewTool}"
YEAR="$(date +%Y)"

LICENSE_TEXT="MIT License

Copyright (c) ${YEAR} SteepWorksAi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the \"Software\"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."

ENCODED=$(printf '%s' "$LICENSE_TEXT" | base64)

echo "── Adding MIT License to $GH_REPO..."

EXISTING=$(gh api "repos/$GH_REPO/contents/LICENSE" 2>/dev/null || echo "")

if [[ -n "$EXISTING" ]]; then
  CURRENT=$(echo "$EXISTING" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
print(base64.b64decode(data['content'].replace('\\n','')).decode().strip())
")
  if [[ "$CURRENT" == "$LICENSE_TEXT" ]]; then
    echo "   LICENSE already correct — skipping."
  else
    SHA=$(echo "$EXISTING" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
    gh api "repos/$GH_REPO/contents/LICENSE" \
      --method PUT \
      --field message="Update LICENSE to MIT ${YEAR}" \
      --field content="$ENCODED" \
      --field sha="$SHA" \
      --silent
    echo "   LICENSE updated."
  fi
else
  gh api "repos/$GH_REPO/contents/LICENSE" \
    --method PUT \
    --field message="Add MIT License" \
    --field content="$ENCODED" \
    --silent
  echo "   LICENSE created."
fi
