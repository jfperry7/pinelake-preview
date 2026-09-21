# Taking the new site live on pinelakecc.com

> ## STATUS — 21 September 2026: the portal has moved and the old site is DOWN
>
> Northstar completed ticket **#996907** today. They did **not** add the new
> hostname alongside the old one — they **moved** the instance. Verified live:
>
> | URL | Result |
> |---|---|
> | `members.pinelakecc.com/web/pages/login` | **200** — real login form |
> | `members.pinelakecc.com/` | **200** — portal home (no password field) |
> | `pinelakecc.com/` | **200** — *"Site is under Maintenance"* |
> | `pinelakecc.com/golf`, `/membership`, `/about`, `/dining` | **404** |
> | `pinelakecc.com/web/pages/login` | **404** — was 200 this morning |
>
> **The club's public website is currently offline.** Every old marketing page
> 404s and the apex serves Northstar's maintenance page.
>
> This inverts the risk calculus in the rest of this document. The section
> below is written around "do not break the working site." There is no longer
> a working site to break — cutover is now recovery, not migration, and the
> sooner the apex points at Cloudflare the sooner the club has a website again.
>
> **Rollback is no longer meaningful.** Reverting the A record to `104.24.9.63`
> restores a maintenance page, not the old site.
>
> Also note: this document predates the move from Vercel to Cloudflare and
> still refers to `vercel.json` and Vercel redirect ordering. The live host is
> a **Cloudflare Worker** and redirects live in `_redirects`, where static
> rules must come **before** dynamic ones — the opposite of Vercel. Treat the
> redirect map below as content, not as instructions.


## What is actually there today

Checked against the live domain, not assumed:

| | |
|---|---|
| **DNS** | Network Solutions (`ns23/ns24.worldnic.com`) — **the club controls this** |
| **A record** | `104.24.9.63` — a Cloudflare IP, but **Northstar's Cloudflare, not the club's** |
| **Platform** | Liferay (Java) — `JSESSIONID` cookies, `/web/pages/*` URLs |
| **Public pages** | **59 URLs** in the sitemap |
| **Member portal** | Same domain: `/login`, `/web/pages/login`, `/c/portal/login` |
| **Email** | Proofpoint (`mx1-us1.ppe-hosted.com`) — unrelated to the website, must not be touched |
| **TTL** | ~1 hour |

Two things follow from this, and they shape everything below.

**The club controls DNS, but not the Cloudflare layer.** The A record is the
club's to change at Network Solutions. The Cloudflare sitting in front of the
current site belongs to Northstar and fronts many club sites, routing by
hostname. So the tempting option — split traffic by path at Cloudflare, so
marketing pages go to Vercel and `/web/*` stays with Northstar — is **not
available to us**. It would have to be done inside Northstar's account, by
Northstar.

**Pointing the domain is all-or-nothing.** Change the A record and the whole
domain leaves Northstar, member portal included. Members would be locked out
the moment it propagates.

---

## The member portal — RESOLVED 21 September 2026

This was the one item with an external dependency, and it is now done.

Northstar moved the Liferay instance to **`members.pinelakecc.com`** under
ticket **#996907** (contact **Rizwan Rizvi**, `support@globalnorthstar.com`,
direct `rizwan.rizvi@globalnorthstar.com`). The CNAME
`members` -> `pinelakecc-com.northstar-connect.com` is live at Network
Solutions, and the wildcard certificate (`*.pinelakecc.com`, Google Trust
Services, expires **12 Nov 2026**, Northstar's to renew) covers it.

**The member login URL is:**

    https://members.pinelakecc.com/web/pages/login

Rizwan asked for the root URL to be mapped to the login button. That is wrong
for a button labelled "Member Login": the root serves a portal **home** page
with no password field on it, and that page links onward to
`/web/pages/login`. The deep link is also the same path members have used for
years, so bookmarks and habit carry over. All login links on the new site
point at the deep link.

**What this cost:** Northstar moved the instance rather than copying it, so the
old public site went down at the same moment. See the status block at the top.

**Still to do at cutover:** the portal redirects at the bottom of `_redirects`
are commented out and must be enabled, so old bookmarked portal links resolve
to the new host. Dynamic (splat) rules must stay last in that file.

---

## Phase 1 — Before touching DNS

Nothing here is risky. All of it can happen while the current site stays up.

### Content gaps

The new site has 8 public pages. The current one has 59. Most collapse
cleanly, but these carry real content today and have nowhere to land:

| Page | What to do |
|---|---|
| **Privacy Policy** | **Must exist at launch.** Linked today and legally relevant. Port it over. |
| **Employment** + application | The club recruits through this. Either build a page or keep it on the Northstar subdomain and link out. |
| **Employee Scholarship Foundation** | A real club program. Decide: port it, or link to the portal. |
| **Mobile Application** | Does the club still promote an app? If so it needs a home. |
| **Caddie Program** | Not covered on the new Golf page. Add a section, or redirect and accept the loss. |
| **Guest Information** | Guest policies. Members link to this. |
| **Staff** | Deliberately omitted — the committee chose three role-specific contacts instead. Redirect to `/contact`. |
| **Picture Gallery** | Already on the enhancements list. Redirect to `/about` for now. |

Decide each of these before launch. A redirect to a page that does not answer
the question is a worse experience than the old page.

### Build items

- [ ] **Form endpoint.** Forms are `mailto:` today. Wire Formspree or Web3Forms.
- [ ] **GA4 measurement ID**, with form submissions and tour requests as conversions.
- [ ] **Remove `X-Robots-Tag: noindex, nofollow`** from `vercel.json`. Leave it on and the site will never rank. This is the single easiest thing to forget.
- [ ] **Canonical tags** on all 13 pages, pointing at `https://pinelakecc.com/...`.
- [ ] **Update `sitemap.xml`** to the real domain.
- [ ] **Add the redirect map** below to `vercel.json`.
- [x] Re-check every login link in the new site. **Done 21 Sep** — all 27 links across 15 pages now point to `https://members.pinelakecc.com/web/pages/login`.

---

## Phase 2 — Vercel and the domain

1. In Vercel, go to the project, then **Settings → Domains**, and add
   `pinelakecc.com` and `www.pinelakecc.com`. Vercel will show the DNS records
   it wants.
2. It will ask for an **A record for the apex** and a **CNAME for `www`**. Use
   the values Vercel shows you rather than any written down elsewhere — they
   have changed these before.
3. **Do not change DNS yet.** Vercel will report "Invalid Configuration" until
   the records point at it. That is expected.
4. Lower the A record TTL at Network Solutions to **300 seconds**, at least
   24 hours before cutover. It is ~1 hour now, which would make a rollback
   slow and uneven.

---

## Phase 3 — Cutover

Do this on a **weekday morning**. Never a Friday, never before a club event.

1. Confirm `members.pinelakecc.com` is live and members have been told.
2. At Network Solutions, change the **A record** for `@` from `104.24.9.63`
   to Vercel's IP, and point `www` at Vercel's CNAME.
3. **Leave MX and TXT records exactly as they are.** Email runs through
   Proofpoint and has nothing to do with the website. The most common way a
   domain move breaks a business is someone tidying up DNS while they are in
   there.
4. Wait for propagation — minutes, with a 300s TTL.
5. Vercel issues the SSL certificate automatically once DNS resolves. Confirm
   `https://pinelakecc.com` loads with a valid certificate before telling
   anyone.

### Verify, in this order

- [ ] `https://pinelakecc.com` and `https://www.pinelakecc.com` both load the new site
- [ ] Certificate valid on both, no browser warning
- [ ] A member can log in at `members.pinelakecc.com/web/pages/login`
- [ ] `pinelakecc.com/web/pages/login` redirects to the portal
- [ ] Spot-check ten old URLs from the redirect map
- [ ] Submit a form and confirm it arrives
- [ ] Send a test email to a club address — this proves MX survived
- [ ] Check on an actual phone, not a resized browser

### If it goes wrong

Change the A record back to `104.24.9.63`. With a 300s TTL you are back within
minutes. That is the whole reason for lowering the TTL first.

---

## Phase 4 — The first fortnight

- [ ] **Google Search Console**: add the property and submit the new sitemap. Expect ranking movement for a few weeks — that is normal after a site change and it settles.
- [ ] Watch Search Console's **Coverage** report for 404s. Any old URL missed from the map shows up here; add a redirect.
- [ ] Update the **Google Business Profile** link.
- [ ] Update the link in the **Instagram, TikTok and Facebook** bios.
- [ ] Raise the TTL back to 3600 once confident.
- [ ] Have Northstar confirm what is still being billed.

---

## Redirect map for `vercel.json`

Every one of these is a live, indexed URL today. Without these they 404 and the
search equity behind them is lost.

**Member portal — must come first; order matters in Vercel**

    /login              ->  https://members.pinelakecc.com/web/pages/login
    /web/:path*         ->  https://members.pinelakecc.com/web/:path*
    /c/:path*           ->  https://members.pinelakecc.com/c/:path*
    /documents/:path*   ->  https://members.pinelakecc.com/documents/:path*
    /o/:path*           ->  https://members.pinelakecc.com/o/:path*

**Golf**

    /golf-shop  /course-tour  /driving-range  /practice-area
    /instruction  /caddie-program                        ->  /golf
    /golf-outing                                         ->  /events

**Tennis**

    /indoor  /outdoor                                    ->  /tennis

**Dining**

    /dining1  /dining-events  /formal-dining-room
    /member-s-grill  /the-lake-room  /terrace-patio-deck1
    /lounge  /snack-bar                                  ->  /dining

**Family and lake**

    /lakefront  /beach-pool  /boats-docks                ->  /family

**Events**

    /weddings  /weddings-special-events  /events-reservation
    /event-request-form  /rooms-capacity                 ->  /events

**Membership**

    /membership-categories  /categories  /membershipprocess
    /request-membership-information  /club-amenities
    /guest-information                                   ->  /membership

**About and contact**

    /about-us  /history  /club-tour  /video-tour
    /gallery  /picture-gallery                           ->  /about
    /staff  /request-information                         ->  /contact

**Housekeeping**

    /en  /welcome  /search  /social-media  /page-not-found
    /sample  /test-page  /old-pages  /submittedinfo      ->  /

**Still to decide — do not redirect until Phase 1 is settled**

    /privacy-policy  /employment  /employment-application
    /scholarship-foundation  /mobile-application
    /christmas-fund-form

`/golf`, `/tennis`, `/dining` and `/membership` already match the new site and
need no redirect.
