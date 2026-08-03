# Pine Lake CC website — handoff / continue-here

**Live:** https://pinelake-preview.vercel.app (root = the cinematic homepage, noindex)
**Repo:** `jfperry7/pinelake-preview` — push to `main` auto-deploys via Vercel.
**Deploy folder (git root):** `Pine Lake Country Club website\pinelake-review-site\`

## State: the 13-page cinematic site is built, cross-linked, and live

| | Pages |
|---|---|
| Homepage | `Home-Cinematic.dc.html` — 7 full-bleed chapters + member voice + facts + inquiry |
| Interiors | Golf, Tennis, Dining, Family, Events, Membership, About, Contact (`*-Cinematic.dc.html`) |
| SEO landing | `SEO-Family-Michigan`, `SEO-Near-Detroit`, `SEO-Golf-Orchard-Lake`, `SEO-Pool-Tennis` |

Older pre-cinematic pages (`Home.dc.html`, `Golf.dc.html`, …) still exist but nothing links to them.

## The interior-page pattern — follow this, don't invent a new one

cinematic hero → story / detail blocks → **at-a-glance** spec table → **member voice** →
**explore next** cross-promo → inquiry form → footer

- Interiors do **not** scroll-snap. Only the homepage does.
- SEO pages deliberately have a **slim header (no nav)** and **zero outbound page links** — they're
  paid-traffic funnels. Don't "fix" that.
- Contact intentionally has no at-a-glance/member-voice; it has contact details + map instead.

## Hard rules (from `design_handoff_pinelake_website\README.md` — the copy bible)

- **No membership tiers, fees, dues, or pricing anywhere.** Verified clean; keep it that way.
- Never "exclusive club." Never scarcity pressure or waitlist comparisons.
- Phone **(248) 682-1300** · 3300 Pine Lake Road, Orchard Lake, MI 48324
- **Never invent brand language.** Every line traces to the README or an existing approved page.
- Voice: Warm, Refined, Rooted, Active, Personal.

## Local preview (no Node on this machine)

Run the Range-enabled static server — a plain server breaks the hero `<video>`:

```
powershell -ExecutionPolicy Bypass -File "<scratchpad>\serve3.ps1"
```
then open `http://localhost:8790/Home-Cinematic.dc.html`.

`support.js` is the runtime that renders the `.dc.html` format. Source of truth is
`design_handoff_pinelake_website\dc-runtime.js`; `support.js` is built from it (registry prepended)
and copied into the deploy folder. **Edit dc-runtime.js, rebuild, copy — never hand-edit support.js.**

Known runtime gotcha already fixed: the `muted` content attribute doesn't set the `muted` IDL
property on elements built with `createElement`, which silently killed hero-video autoplay for
anyone without Chrome media-engagement history. The runtime now sets it explicitly.

## Outstanding — what's left

### Waiting on the club (all bracketed and visible in place, not hidden)
- **Testimonials** — 11 pages still say `[TESTIMONIAL — TO BE COLLECTED]`. Only one real quote
  exists so far (the Drummond family, on the homepage). Each page's placeholder describes the
  kind of quote that belongs there.
- **Venue names & menus** — Dining (`[TO BE PROVIDED]`)
- **Signature event names & dates** — Events (`[TO BE PROVIDED]`)
- **Exact course date + the 1921 milestone** — About (`[TO BE CONFIRMED]`)
- **Wedding + archival/vintage photography** — the two real gaps in the photo library
- **Member Login URL** — `https://members.pinelakecc.com` is still a placeholder; confirm

### Technical, before launch
- **Forms only simulate submission.** Wire to the Membership Director's inbox or the club's CRM,
  and fire analytics: inquiry submit = conversion #1, tour CTA click = #2.
- **Remove `noindex`** only when the placeholders above are resolved. It's set in `vercel.json`
  (`X-Robots-Tag`) and `_headers`. Publishing placeholder content to search engines is hard to undo.
- **SEO metadata** — unique `<title>` + meta description per page, and Schema.org
  LocalBusiness/CountryClub markup, per the README. Not done yet.
- **Clean URLs** for the SEO pages (e.g. `/family-country-club-michigan`) rather than `.dc.html`.

### Design decisions still open
- **Main hero H1** — still the original keyword line. Alternatives were offered; none picked.
  Note it carries real SEO weight (primary keyword), so changing it is a tradeoff, not a freebie.
- **The junior-putting photo** — better as a *card* on Golf or Family than a chapter background.
  Also: the version on hand is an AI reconstruction of real children's faces. Get the camera
  original from the photographer before it ships.
- **Photo retouching** — 29 full-res masters sit in `photos-for-retouch\` named by slot, with
  `_RETOUCH-GUIDE.csv` listing placements, role (hero 2400px vs card 1600px) and orientation.
  Lightroom for batch consistency across shoots; Photoshop for the handful needing surgery.
  Neither is installed — only Acrobat. Round-trip: export `<slot>.jpg`, drop in, filenames match.
- **Children's faces** are visible in several live photos. Confirm the club holds releases.

## Assets

- `club-assets\` — ~5,700 raw club photos/videos by year/activity; `club-assets\Selects\` = curated
- `photos-for-retouch\` — the 29 in-use masters (+ `_superseded\` for retired ones)
- Portrait-orientation images crop badly at full bleed. Still portrait: `pool`, `beach`,
  `golf-junior`, `tennis-junior`. `pool` is used 5× and is the one worth converting.
- `tennis-indoor.jpg` is a still from `IMG_2802.MOV`, not a photograph — softest image doing a big
  job (homepage chapter 3). A real landscape photo of the indoor courts would beat any retouch.
