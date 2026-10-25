# Reconnect public website

Dependency-free static site: plain HTML, one CSS file, no JavaScript, no build step, no external fonts, CDNs or trackers. Light and dark themes follow `prefers-color-scheme`.

| File | Purpose |
|------|---------|
| `index.html` | Landing page |
| `privacy.html` | Privacy policy (use this URL in App Store Connect and Google Play) |
| `terms.html` | Terms of service |
| `support.html` | Support contact and FAQ |
| `delete-account.html` | Account and data deletion instructions (use this URL for Google Play's account-deletion requirement) |
| `404.html` | Not-found page (Cloudflare Pages and Netlify serve it automatically) |
| `styles.css` | All styling |
| `robots.txt`, `sitemap.xml` | Crawler files (use `https://reconnect.app`; change if the domain differs) |
| `_headers` | Security headers (CSP `default-src 'self'`, HSTS, `frame-ancestors 'none'`, etc.), Netlify / Cloudflare Pages format |

## Preview locally

```bash
cd web-site
python3 -m http.server 8000
# open http://localhost:8000
```

Internal links are root-relative (`/privacy.html`), so serve from the `web-site/` folder root (not from a sub-path). `_headers` is only applied by the host, not by the Python server.

## Deploy

### Cloudflare Pages

1. Create a Pages project connected to this repository.
2. Build command: leave empty. Build output directory: `web-site`. (Or `npx wrangler pages deploy web-site`.)
3. Add the custom domain `reconnect.app`. Cloudflare serves `/privacy` and `/privacy.html`; `_headers` and `404.html` are picked up automatically.

### Netlify

1. New site from Git. Build command: empty. Publish directory: `web-site`. (Or `netlify deploy --prod --dir web-site`.)
2. Add the custom domain. `_headers` and `404.html` are picked up automatically.

After deploying, check the response headers (for example `curl -I https://reconnect.app/`) and test the pages in a CSP-aware browser; the CSP blocks inline scripts and inline `style` attributes, so keep any future additions in external files.

Also set the server's `ALLOWED_ORIGINS` (Phase 1.5 of the production readiness plan) to this site's origin if it ever calls the API.

## Before publishing: placeholder checklist

The policy and terms contain placeholders. Search the folder (`grep -rn "\[" web-site/*.html`) and replace every one:

- [ ] `[COMPANY LEGAL NAME]` - privacy.html, terms.html, footer on every page
- [ ] `[ADDRESS]` - privacy.html, terms.html
- [ ] `[DATE]` - effective and last-updated dates in privacy.html and terms.html
- [ ] `[GOVERNING LAW]` - terms.html (governing law and courts)
- [ ] `https://reconnect.app` - canonical URLs in each page, `sitemap.xml`, `robots.txt` if the final domain differs
- [ ] Mailboxes `privacy@reconnect.app` and `support@reconnect.app` exist and are monitored
- [ ] Replace the "Coming soon" text badges on `index.html` with the official App Store / Google Play badges (and their links) once the apps are live. Official badge images must be self-hosted to keep the CSP at `'self'`.
- [ ] Optional: add a 1200x630 PNG social-share image and `og:image` meta tags (none is included, so no binary assets ship with the site)

The privacy page and terms page also carry a visible "ITEMS TO FILL BEFORE PUBLISHING" HTML comment listing these.

### Facts to double-check against the implementation

The policy describes the product as specified in `docs/API_CONTRACT.md` and `docs/PRODUCTION_READINESS_PLAN.md`. Confirm these still hold at launch, and edit the policy if they do not:

- Contacts are stored only as HMAC (server pepper) hashes plus display name; raw values are not kept.
- Only the city is stored, never coordinates; location is visible only to mutual matches who enabled sharing.
- Providers named: hosting provider, Twilio Verify (SMS), error monitoring (for example Sentry). Name them explicitly if you prefer.
- Retention: immediate hard delete on account deletion, backups purged within 30 days.
- Self-imposed timelines on `delete-account.html` (email requests aim for 7 days, at most 30) and the "two business days" support response on `support.html`. Adjust to what you can honour.
- In-app path "Profile > Delete account" (with password confirmation) and a data export available on request.
- Minimum age 17 (app store rating); the policy also states the 13/16 statutory floors.
- IP address, app version and OS are described as collected for security and diagnostics.
- Store privacy forms (App Store privacy labels, Google Play Data safety) must match this policy.

## Not legal advice

The privacy policy and terms of service here are drafts written to match how the product works. They are **not legal advice**. Have qualified counsel review them (including GDPR/UK GDPR, CCPA/CPRA, COPPA and app store requirements for your markets) before publishing.
