# Pine Lake CC website — start here

Last updated **22 September 2026, afternoon**. Written so a session with no memory
of the build can pick this up cold. Read this before touching anything.

> ## STATUS, 21 September 2026, 9:30pm ET: LIVE. Website and member portal both up.
>
> `pinelakecc.com` serves the new site from the Cloudflare Worker on nameservers
> `agustin`/`paige.ns.cloudflare.com`. `members.pinelakecc.com` (portal and app)
> is back after an evening outage caused by the migration itself - see the
> RESOLVED section at the bottom of `LAUNCH.md`, and trap 7 below. Club email
> was never affected. The block that follows is the pre-cutover picture, kept
> for context.
>
> **22 Sept:** post-launch QA done and shipped (form confirmation copy,
> http->https, `lang`, security headers) and the hero video now answers byte
> ranges with 206 from `worker.js` - see "Post-launch QA" at the end of
> `LAUNCH.md` for what is still open.
>
> **22 Sept, 2:25pm: `MAIL_TEST_TO` is OFF.** `send.pinelakecc.com` is verified
> in Resend and forms send from `forms@send.pinelakecc.com` straight to
> Melanie and Anna. The comment in `wrangler.jsonc` says how to turn the test
> routing back on.
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
> not an optional migration. Everything else is finished.
>
> **It is a nameserver move, not an A-record change.** A Cloudflare Worker has
> no IP for external DNS to point at, and a Worker Custom Domain requires the
> zone to be active in the club's own Cloudflare account. So the zone has to
> leave Network Solutions' nameservers, which drags the club's Microsoft 365,
> Proofpoint and SendGrid records along with it. **That, not the website, is
> the risk.** The full record inventory and the order of operations are in
> `LAUNCH.md` — read its status block before the phases.
>
> **Rollback no longer means anything.** Reverting the A record to
> `104.24.9.63` restores a maintenance page, not the old site — and a
> nameserver move does not roll back quickly either: the `.com` delegation
> carries a 48-hour TTL. Correctness before the switch is the only safety net.
>
> **The portal leans on our redirects.** 13 links inside the member portal
> still point at `pinelakecc.com` and work only because `_redirects` forwards
> them. Deliberately left that way (Northstar changes have broken things
> twice). Never remove the portal block in `_redirects`; if the site ever
> moves host again, those rules move with it. List in `NORTHSTAR-FIX-LIST.md`.

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
- Custom domains are attached on the Worker's **Domains** tab - and a Worker
  Custom Domain **requires the zone to be active in this Cloudflare account**.
  There is no IP to point external DNS at. That is why the cutover is a
  nameserver move, not an A-record change.
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

### 7. A subdomain that CNAMEs into someone else's Cloudflare breaks when the zone moves onto Cloudflare

`members.pinelakecc.com` is a CNAME into Northstar's Cloudflare account. While
`pinelakecc.com` lived at Network Solutions, that just worked. The moment the
zone became active in the club's own Cloudflare account, Cloudflare saw two
accounts claiming the name and refused to route it (**error 1014**, then
**1000**) until Northstar's custom hostname for it was ownership-verified and
active. Members and the app were locked out for about five hours on cutover
night.

The tell is cheap to check before any DNS move: if a subdomain's CNAME target
resolves to Cloudflare IPs and you are moving the zone onto Cloudflare, the
target's owner must add `_cf-custom-hostname.<name>` and `_acme-challenge.<name>`
records for you **before** the switch. Ask them for those first. Also: the
customer-side record must be a **CNAME** to their target - an A record to a
Cloudflare IP is documented-unsupported and yields error 1000 even when their
side is correct.
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
| Hero video | `worker.js` serves byte ranges for `.mp4` itself (206, 416, HEAD); Cloudflare's asset server has no Range support. Images stay native via `run_worker_first` exclusions. 22 Sept |

**One switch is deliberately still ON and must come off at launch:**

`MAIL_TEST_TO` in `wrangler.jsonc` — while set, every form submission goes to
the club Gmail instead of Melanie and Anna. **It is not a free-standing
switch.** Resend only delivers to the account owner's own address until a
domain is verified, and `MAIL_FROM` is still Resend's shared test sender, so
removing this line before Phase 2 of `LAUNCH.md` makes every enquiry fail with
a 502. Verify a Resend sending domain first.

The other two switches are gone. Indexing used to be a blanket
`X-Robots-Tag` in `_headers` plus `Disallow: /` in `robots.txt`; both are now
a hostname guard in `worker.js`, because one deployment serves both the
staging `.workers.dev` URL and the live domain and no blanket rule can be
right for both. Anything that is not `pinelakecc.com` or `www.pinelakecc.com`
gets `noindex, nofollow` and a `Disallow: /` robots.txt; the live domain gets
neither. Nothing to remember, and staging cannot become duplicate content
against the club's own pages after launch.

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

**Done 21 Sept:** the portal redirects at the bottom of `_redirects` are now
enabled, so old bookmarked portal links reach the new host. The static
`/login` rule sits above the splats and the splats stay last in the file.

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

**SPF is at 7 of 10 permitted DNS lookups** — counted live, with the
arithmetic in `LAUNCH.md`. The record already covers Microsoft 365, Proofpoint,
SendGrid and Amazon SES. SendGrid has live DKIM keys, so something is actively
sending through it — do not remove includes without checking Proofpoint's DMARC
reports first. **Getting SPF wrong takes down the club's email.**

**So do not touch this record for Resend.** Verify a sending *subdomain*
instead, such as `send.pinelakecc.com`. Resend recommends a subdomain anyway,
for sending reputation, and its SPF and DKIM records then land on the
subdomain and leave the apex record alone. That takes the riskiest remaining
step out of the launch altogether. See Phase 2 of `LAUNCH.md`.

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
| `../../old-site-archive-2026-09-21/` (project root, two levels up - not one) | The old site, captured 21 Sept. **Now the only copy that exists** — Northstar took the live pages down the same day, and the Wayback Machine never captured them. Outside the repo so it is never served, which also means **it is not in git and lives on Josh's machine alone.** |

There is also a live checklist artifact, "Pine Lake Launch Runbook", in Josh's
Claude artifacts. Ticks persist between sessions.

---

## Still open

- **THE CUTOVER — the only thing that matters right now.** The club has no
  public website until `pinelakecc.com` is served by the Cloudflare Worker,
  and that means **delegating the zone to Cloudflare**, not editing a record
  at Network Solutions. Full procedure, DNS record inventory and ordering in
  `LAUNCH.md`. Do Resend's sending domain (Phase 2) before removing
  `MAIL_TEST_TO`, and confirm club email still flows before attaching the
  Worker. Network Solutions' form is mislabelled — see below.
- **Members need telling** that the portal moved to
  `members.pinelakecc.com/web/pages/login`. They will be logged out once, since
  `JSESSIONID` is host-only. A draft notice exists in the session history.
- **Back up the archive off this machine.** See the table above. One disk
  failure and the club's old site is gone for good.
- **Four old pages have nowhere to land** and will 404 after cutover:
  `/employment-application`, `/scholarship-foundation`, `/mobile-application`,
  `/christmas-fund-form`. Listed at the bottom of `_redirects`.
- **Resend domain verification** before launch, so forms send from a club
  address rather than `onboarding@resend.dev`. Do it on a **subdomain**, so
  the apex SPF record is never touched. Until it is done, `MAIL_TEST_TO` must
  stay set: Resend will not deliver to Melanie and Anna from an unverified
  domain, so removing the switch first turns every enquiry into a 502.
  Phase 2 of `LAUNCH.md`.
- **GA4 custom dimensions** (`inquiry_type`, `routed_to`) need registering in
  the GA4 admin before those parameters appear in reports.
- **Privacy notice needs a legal read.** The client has indicated he is not
  pursuing this; it is recorded here as a known risk, **not a task to raise
  again.**
- **Enhancements** — Meet the Pro sections, wedding gallery. See
  `ENHANCEMENTS.md`; both are blocked on photography the club does not have.
