# SteepWorksAI — Product Landing Page Prompt

Use this prompt whenever you need to generate a `docs/index.html` for a new SteepWorksAI product.

---

## How to use

Fill in the **Inputs** block below, then paste this entire prompt to Claude Code:

```
Generate a docs/index.html for a SteepWorksAI product using the prompt at
homepageassets/prompts/product-page.md with these inputs:

PRODUCT_NAME:   <name>
TAGLINE:        <short tagline shown after the em-dash in the browser tab>
BADGE:          <text inside the pill badge, e.g. "Chrome Extension · Free · Open Source">
HERO_H1:        <two-line headline, use <br> for the line break>
HERO_SUB:       <2–3 sentence description shown below the headline>
CHROME_URL:     <Chrome Web Store listing URL, or NONE>
EDGE_URL:       <Edge Add-ons listing URL, or NONE>
GITHUB_REPO:    steepworksai/<RepoName>
ICON_FILE:      <filename, e.g. icon128.png>
HOW_IT_WORKS:   <list of 3–4 steps: "Step title | Step description">
FEATURES:       <list of 5–6 features: "emoji | Title | Description">
PRIVACY_ROWS:   <list of rows: "What happens | Detail">
VIDEO_EMBED:    <YouTube embed URL or NONE>
```

---

## CTA buttons (always render all that apply, in this order)

Every page has up to 4 fixed CTA buttons. The inputs that drive them are
`CHROME_URL`, `EDGE_URL`, and `GITHUB_REPO`. Omit a button only if its URL
is `NONE` or not provided.

| # | Button | Style class | Label | href |
|---|--------|-------------|-------|------|
| 1 | Chrome | `.cta .cta-chrome` | `[Chrome SVG icon] Add to Chrome — It's Free` | `CHROME_URL` |
| 2 | Edge   | `.cta .cta-edge` | `[Edge SVG icon] Add to Edge — It's Free` | `EDGE_URL` |
| 3 | Star   | `.cta .cta-gh` | `⭐ Star on GitHub` | `https://github.com/{GITHUB_REPO}` |
| 4 | Contribute | `.cta .cta-contribute` | `🤝 Contribute` | `https://github.com/{GITHUB_REPO}` |

**Star and Contribute are always rendered** (GITHUB_REPO is always required).
Chrome and Edge are only rendered when their URL is not NONE.

**Browser icon SVGs** (inline, copy exactly into the button):
```html
<!-- Chrome icon -->
<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 100 100" style="flex-shrink:0"><path d="M50,50L50,5A45,45,0,0,1,88.97,72.5Z" fill="#EA4335"/><path d="M50,50L88.97,72.5A45,45,0,0,1,11.03,72.5Z" fill="#FBBC05"/><path d="M50,50L11.03,72.5A45,45,0,0,1,50,5Z" fill="#34A853"/><circle cx="50" cy="50" r="27" fill="#fff"/><circle cx="50" cy="50" r="20" fill="#4285F4"/></svg>

<!-- Edge icon -->
<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 100 100" style="flex-shrink:0"><path d="M85,44C85,24,69,8,50,8C31,8,15,24,15,44c0,10,4,20,12,27h46C81,64,85,54,85,44zM50,22c11,0,21,9,21,21H29C29,31,39,22,50,22z" fill="#0078D7"/><path d="M27,71c7,8,16,13,23,13c12,0,23-7,28-17H27Z" fill="#33AADC"/></svg>
```

---

## Design system (do not change these)

```
Background:   #f9fafb
Body text:    #111827
Headings:     #1f2937
Secondary:    #6b7280
Muted:        #9ca3af
Accent:       #2d6b2d  (forest green)
Accent-2:     #c9920e  (gold)
Border:       #e5e7eb
Card bg:      #ffffff
Badge bg:     #f0f9f0   border: #a8d5a8   text: #2d6b2d
Font:         system-ui, -apple-system, sans-serif
Border-radius on cards: 12px
Border-radius on CTA buttons: 12px
Border-radius on logo: 16px
```

CTA button CSS:
```css
/* base — Chrome */
.cta {
  display: inline-flex; align-items: center; gap: 8px;
  padding: 14px 28px; border-radius: 12px;
  font-weight: 700; font-size: 16px; text-decoration: none; color: #fff;
  background: linear-gradient(135deg, #2d6b2d, #c9920e);
  box-shadow: 0 4px 18px rgba(45,107,45,0.35);
}
/* Edge — same white style as Chrome so the Edge icon pops */
.cta-edge {
  background: #fff;
  color: #1f2937;
  border: 1.5px solid #dadce0;
  box-shadow: 0 1px 4px rgba(0,0,0,0.1);
}
/* Star on GitHub */
.cta-gh {
  background: linear-gradient(135deg, #1f2937, #374151);
  box-shadow: 0 4px 18px rgba(0,0,0,0.2);
}
/* Contribute */
.cta-contribute {
  background: transparent;
  border: 2px solid #2d6b2d;
  color: #2d6b2d;
  box-shadow: none;
}
/* Chrome — white bg so the colorful Chrome icon pops */
.cta-chrome {
  background: #fff;
  color: #1f2937;
  border: 1.5px solid #dadce0;
  box-shadow: 0 1px 4px rgba(0,0,0,0.1);
}
```

---

## Page structure

Generate a single self-contained HTML file with **inline CSS only** (no external stylesheets or JS frameworks). Follow this section order exactly:

### 1 — `<head>`
- charset UTF-8, viewport meta
- `<title>{PRODUCT_NAME} — {TAGLINE}</title>`
- Favicon: `<link rel="icon" type="image/png" sizes="128x128" href="{ICON_FILE}">`
- All CSS inline in `<style>`

### 2 — Hero + CTAs  `.hero`  (max-width 720px, centered, padding 80px 24px 60px)
- `.logo-wrap`: product icon (64×64px, border-radius 16px, box-shadow rgba(99,102,241,0.25)) + product name (28px, weight 900, #1f2937)
- `.badge`: pill with BADGE text
- `<h1>`: HERO_H1 (42px, weight 900, line-height 1.15)
- `.sub`: HERO_SUB (18px, #6b7280, max-width 540px, margin-bottom 36px)
- `.cta-group`: flex row, gap 12px, wraps on mobile — render the CTA buttons per the table above

### 3 — Features  `.features`  (max-width 720px, margin 60px auto 0)
- h2 "Features" (26px, weight 800, centered)
- `.grid` (auto-fit, minmax 200px): each `.feature` card has emoji `.icon` (24px), h3 (15px, weight 700), p (13px, #6b7280)

### 4 — How it works  `.how`  (only if HOW_IT_WORKS is provided)
- h2 "How it works" (26px, weight 800)
- `.steps` grid (auto-fit, minmax 150px): each `.step` card has step number label (12px, uppercase, #2d6b2d), h3, p

### 5 — Video  `.video-section`  (only if VIDEO_EMBED is not NONE)
- h2 "See it in action" (26px, weight 800)
- 16:9 iframe embed with border-radius 16px and box-shadow

### 6 — Bottom CTA  `.cta-bottom`  (max-width 720px, margin 60px auto, centered)
- Repeat the exact same `.cta-group` from the hero — captures users who scrolled all the way through

### 7 — Privacy  `.privacy`  (only if PRIVACY_ROWS is provided)
- h2 "Privacy first" (26px, weight 800, centered)
- Table with columns "What happens" | "Detail"
  - `th`: background #f9fafb, 13px, weight 700, #374151
  - `td`: 13px, #4b5563, bottom border #f3f4f6; last row no border

### 7 — Footer
```html
<footer>
  © 2026 SteepWorksAi ·
  <a href="https://github.com/{GITHUB_REPO}" target="_blank">GitHub</a> ·
  <a href="privacy.html">Privacy Policy</a> ·
  <a href="https://github.com/{GITHUB_REPO}/issues" target="_blank">Support</a>
</footer>
```

---

## Rules

- **No external CSS, fonts, or JS.** Fully self-contained.
- **Mobile responsive.** At ≤600px: h1 drops to 28px, grids become single column.
- **Inline everything.** One `<style>` block in `<head>`, no `<script>` tags.
- **Do not invent facts.** Only use content from the Inputs block above.
- **Omit sections** that have no input (e.g. no video → no `.video-section`).
- **Consistent spacing.** Section bottom margins: 60px.
- Match the existing pages exactly in CSS style — do not introduce new design patterns.
