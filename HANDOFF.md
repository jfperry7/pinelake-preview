# Pine Lake CC website — start here

Last updated **21 September 2026, evening**. Written so a session with no memory
of the build can pick this up cold. Read this before touching anything.

> ## READ THIS FIRST: the club has no public website right now
>
> Northstar completed ticket #996907 on 21 Sept. They **moved** the Liferay
> instance to `members.pinelakecc.com` rather than adding the hostname
> alongside the old one — so the old public site went down with it.
>
> | URL | Now |
> |---|---|
> | `members.pinelakecc.com/web/pages/login` | 200, real login form |
> | `pinelakecc.com/` | 200, *"Site is under Maintenance"* |
> | `pinelakecc.com/golf`, `/membership`, `/about`, `/dining` | **404** |
>
> **The one remaining task is the DNS cutover**, and it is now a recovery job,
> not an optional migration. Everything else is finished. The procedure is in
> `LAUNCH.md` — read its status block at the top before the phases, because the
> phases were written assuming a working old site that needed protecting.
>
> **Rollback no longer means anything.** Reverting the A record to
> `104.24.9.63` restores a maintenance page, not the old site.

| | |
|---|---|
| **Staging** | https://pinelake-preview.1902pinelakecc.workers.dev |
| **Target** | `pinelakecc.com` — **not moved yet; this is the one remaining task** |
| **Member portal** | `members.pinelakecc.com/web/pages/login` — live, Northstar-hosted |
| **Repo** | `jfperry7/pinelake-preview`, push to `main` auto-deploys |
| **Git root** | `Pine Lake Country Club website\pinelake-review-site\` |
| **Host** | Cloudflare **Worker** (not Pages — see below) |
| **Account** | `1902pinelakecc@gmail.com` |
| **Client** | Josh Perry, The JRT Agency. Not a developer — explain in plain terms. |

---

## Six things that will bite you

These are all mistakes already made once. Do not repeat them.

### 1. This is a Worker, not Pages

Cloudflare's Git integration now creates a Worker with static assets. That means:

- **`functions/` does nothing on its own.** That is a Pages convention. `worker.js`
  is the entry point and routes `/api/inquiry` to `functions/api/inquiry.js`;
  everything else goes to `env.ASSETS.fetch()`.
- Custom domains are attached on the Worker's **Domains** tab.
- `_redirects` and `_headers` still work as normal.

### 2. `wrangler.jsonc` wipes dashboard variables

The build runs `npx wrangler deploy`, which treats `wrangler.jsonc` as the
complete configuration and **deletes any runtime variable set in the dashboard
that the file does not declare.** Mail variables were silently erased this way
several times before anyone worked out why.

**Non-secret variables belong in `wrangler.jsonc` under `vars`. Secrets stay in
the dashboard** — wrangler does not touch those.

### 3. Inline SVG does not survive the runtime

`support.js` rebuilds the DOM with `document.createElement`, not
`createElementNS`, so every node inside an `<svg>` comes back in the HTML
namespace. The tell is the rendered attribute reading lowercase `viewbox`.
`<path>` and `<circle>` then draw nothing, while `<text>` dumps its content as
stray words on the page.

**Any vector work must be a base64 data-URI on an `<img>`.** The Pine Lake
outline on the Membership page is done this way.

### 4. `.assetsignore` is the only thing keeping files private

Without it, Cloudflare serves the entire repo root — which is how `LAUNCH.md`,
with the club's DNS and migration plan in it, became publicly readable twice.
`.vercelignore` means nothing here.

Anything added to the repo that must not be public goes in `.assetsignore`.

### 5. The form endpoint's status codes mean different things

- **500** — `RESEND_API_KEY` is missing.
- **502** — the key works and **Resend rejected the request**. Usually
  `MAIL_FROM` pointing at an unverified domain.

These were confused once, which led to re-doing setup that was already correct.
Check the code before concluding anything.

### 6. DNS answers are cached; "the record does not exist" is unreliable

Once a name has been queried, resolvers hold the answer for the TTL — including
negative answers. A lookup saying a record is absent may just be a stale cache.
Use a resolver that has never seen the name, or flush first, before telling
anyone a record is missing.

---

## Current state

**The site is finished and live on staging,** 14 pages plus a 404, all checks
passing. It is **not yet on the real domain** — see the block at the top.

| Piece | State |
|---|---|
| Pages | 14, named for their URLs (`golf.html`, `about.html`, `index.html`) |
| Redirects | All 59 old URLs mapped in `_redirects` |
| Forms | **Working.** Resend via `/api/inquiry`, tested both routes |
| Analytics | GA4 `G-SHF5ZLF3GT`, guarded to the live domain |
| Canonicals | All 14 pages, self-referential |
| 404 page | `404.html` — *"That page has moved on."* |
| Privacy | `/privacy` — newly written, **not legally reviewed** |
| Member login | All 27 links repointed to `members.pinelakecc.com/web/pages/login` (21 Sept) |

**Three switches are deliberately still ON and must come off at launch:**

1. `X-Robots-Tag: noindex, nofollow` in `_headers`
2. `Disallow: /` in `robots.txt`
3. `MAIL_TEST_TO` in `wrangler.jsonc` — while set, every form submission goes
   to the club Gmail instead of Melanie and Anna

Either of the first two left in place keeps the site out of Google entirely.

---

## The member portal — done, 21 September 2026

The portal is a Liferay app run by **Northstar**. It now lives at
**`members.pinelakecc.com`** and works. Ticket **#996907**; contact **Rizwan
Rizvi**, `support@globalnorthstar.com` (direct `rizwan.rizvi@globalnorthstar.com`).

**The member login URL is:**

    https://members.pinelakecc.com/web/pages/login

Use the deep link, not the root. Rizwan asked for the root URL to be mapped to
the login button, but the root serves a portal **home** page with no password
field on it — it links onward to `/web/pages/login`. The deep link is also the
path members have used for years, so bookmarks carry over. **All 27 login links
across the 15 pages were repointed on 21 Sept** and no longer need touching at
cutover.

DNS and certificate are both settled: CNAME `members` ->
`pinelakecc-com.northstar-connect.com` at Network Solutions, wildcard
certificate `*.pinelakecc.com` from Google Trust Services, **expiring 12 Nov
2026** and Northstar's to renew.

**The cost of how they did it:** they moved the instance instead of copying it,
so the old public site went offline the same day. See the block at the top.

**Still to do at cutover:** enable the commented-out portal redirects at the
bottom of `_redirects`, so old bookmarked portal links reach the new host.
Dynamic (splat) rules must stay last in that file.

---

## DNS facts

| | |
|---|---|
| Registrar & DNS | Network Solutions (`ns23`/`ns24.worldnic.com`) |
| Login | Melanie Pfeffer's personal Yahoo. Registrant is `controller@pinelakecc.com` |
| Current apex | `104.24.9.63` — Northstar's Cloudflare. **This is the rollback value.** |
| Email | Proofpoint + Microsoft 365. **Never touch MX or TXT during a cutover.** |
| Expiry | April 2028 |
| Wildcard | A `*` record sends every unmatched subdomain to `64.135.11.57`, an old 365 Datacenters host nothing appears to use |

**SPF is at 7 of 10 permitted DNS lookups.** Adding Resend's include is
possible but tight, and the record already covers Microsoft 365, Proofpoint,
SendGrid and Amazon SES. SendGrid has live DKIM keys, so something is actively
sending through it — do not remove includes without checking Proofpoint's DMARC
reports first. **Getting SPF wrong takes down the club's email.**

Network Solutions' DNS form is mislabelled: **"Refers to" is the name you are
creating; "Alias to" is the destination.** That is backwards from how the words
read and it has already caused one broken record.

---

## Copy rules — still binding

From `design_handoff_pinelake_website\README.md`:

- **No membership tiers, fees, dues or pricing anywhere.**
- Never "exclusive club". No scarcity pressure or waitlist language.
- **Never invent brand language.** Every line traces to an approved source.
- **No unverifiable superlatives.** "Only full-service club in Southeast
  Michigan" was removed from eight places for exactly this reason.
- **No response-time promises.** "Within one business day" was removed
  everywhere at the client's request.
- Voice: Warm, Refined, Rooted, Active, Personal.
- Plain ASCII apostrophes in body copy — the site uses them throughout.
- Phone **(248) 682-1300** · 3300 Pine Lake Road, Orchard Lake, MI 48324

**Headlines follow a lifestyle test**, set by committee member Dan Vivian: a
headline says what you experience, not what the club owns. "Not just a place to
play. A place to be." rather than "Willie Park Jr. laid it out."

---

## Local preview

No Node on this machine. Use the Range-enabled static server from the
scratchpad — a plain server breaks the hero video:

```
powershell -ExecutionPolicy Bypass -File "<scratchpad>\serve3.ps1"
```

Then open `http://localhost:8790/golf.html`. **Its clean-URL slug map is stale
after the file rename** — request the actual filenames, not `/golf`.

For screenshots: headless Chrome will not make a window narrower than ~497px,
so "mobile" captures are really a 497px viewport cropped. To test real phone
widths, load the page in an iframe of the width you want.

---

## Other documents

| File | What it holds |
|---|---|
| `LAUNCH.md` | Full cutover procedure, DNS values, redirect map, rollback |
| `ENHANCEMENTS.md` | Deferred work and what the club must supply for each |
| `COMMITTEE-NOTE.md` | Draft note to the committee — **stale**, still mentions Formspree |
| `../old-site-archive-2026-09-21/` | The old site, captured 21 Sept. **Now the only copy that exists** — Northstar took the live pages down the same day, and the Wayback Machine never captured them. Outside the repo so it is never served, which also means **it is not in git and lives on Josh's machine alone.** |

There is also a live checklist artifact, "Pine Lake Launch Runbook", in Josh's
Claude artifacts. Ticks persist between sessions.

---

## Still open

- **THE CUTOVER — the only thing that matters right now.** The club has no
  public website until the apex A record moves off `104.24.9.63` to the
  Cloudflare Worker. Full procedure in `LAUNCH.md`. Apex TTL is **1800s (30
  min)**. DNS is at Network Solutions, whose form is mislabelled — see below.
  At the same time: remove `X-Robots-Tag: noindex` from `_headers`, change
  `Disallow: /` in `robots.txt`, delete `MAIL_TEST_TO` from `wrangler.jsonc`,
  and uncomment the portal redirects in `_redirects`.
- **Members need telling** that the portal moved to
  `members.pinelakecc.com/web/pages/login`. They will be logged out once, since
  `JSESSIONID` is host-only. A draft notice exists in the session history.
- **Back up the archive off this machine.** See the table above. One disk
  failure and the club's old site is gone for good.
- **Four old pages have nowhere to land** and will 404 after cutover:
  `/employment-application`, `/scholarship-foundation`, `/mobile-application`,
  `/christmas-fund-form`. Listed at the bottom of `_redirects`.
- **Resend domain verification** before launch, so forms send from a club
  address rather than `onboarding@resend.dev`. This is the SPF change above,
  and it is the riskiest remaining step — the record is at 7 of 10 lookups and
  carries the club's live email.
- **GA4 custom dimensions** (`inquiry_type`, `routed_to`) need registering in
  the GA4 admin before those parameters appear in reports.
- **Privacy notice needs a legal read.** The client has indicated he is not
  pursuing this; it is recorded here as a known risk, **not a task to raise
  again.**
- **Enhancements** — Meet the Pro sections, wedding gallery. See
  `ENHANCEMENTS.md`; both are blocked on photography the club does not have.
