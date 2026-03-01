# SteepWorksAI Homepage — Project Notes

## Repo
- GitHub: `steepworksai/steepworksai.github.io`
- Serves at: `steepworksai.com` (custom domain via CNAME)
- Deployed via GitHub Pages from `main` branch root

## Related repos
- `../FormBuddy` → `formbuddy.steepworksai.com`
- `../ScreenReader` (Briefer) → `briefer.steepworksai.com`

## DNS setup (Cloudflare)
- Domain is on Cloudflare. To configure DNS for GitHub Pages, run:
  ```bash
  bash scripts/setup-dns.sh
  ```
- Requires `.env.local` (git-ignored) with:
  ```
  CF_TOKEN=your_cloudflare_api_token_here
  ```
- Token needs "Edit zone DNS" permission scoped to `steepworksai.com`
- Script auto-fetches Zone ID — no need to provide it manually
- Script sets 4 GitHub Pages A records + www CNAME, all with Cloudflare proxy OFF (grey cloud)
- Proxy must be off so GitHub can issue its Let's Encrypt cert and "Enforce HTTPS" works

## GitHub Pages steps (one-time)
1. Push files to `main`
2. Settings → Pages → Deploy from branch → `main` / root
3. Settings → Pages → Custom domain → `steepworksai.com`
4. Run `bash scripts/setup-dns.sh` to fix DNS
5. Wait ~5 min → "Enforce HTTPS" becomes available → enable it
