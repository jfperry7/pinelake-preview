# Taking the new site live on pinelakecc.com

> ## STATUS - 21 September 2026, evening
>
> **The club has no public website.** Northstar completed ticket **#996907**
> today but **moved** the Liferay instance to `members.pinelakecc.com` rather
> than adding the hostname alongside the old one, so the old public site went
> down with it. Re-verified against live DNS and HTTP this evening:
>
> | URL | Result |
> |---|---|
> | `members.pinelakecc.com/web/pages/login` | **200** - real login form |
> | `pinelakecc.com/` | **200** - *"Site is under Maintenance"* |
> | `pinelakecc.com/golf` | **404** |
> | `pinelake-preview.1902pinelakecc.workers.dev/` and `/golf` | **200** - the new site |
>
> Cutover is therefore **recovery, not migration**. There is no working site
> left to protect, so the risk calculus that shaped the original phases no
> longer applies - except for email, which is untouched and must stay that way.
>
> **Rollback is not meaningful for the website.** Reverting to `104.24.9.63`
> restores a maintenance page, not the old site.
>
> ### Two things found on 21 Sept that change the plan
>
> **1. You cannot point an A record at a Cloudflare Worker.** The phases below
> originally said to change the apex A record at Network Solutions. That works
> for Vercel. It does not work here. A Worker Custom Domain
> [requires an active Cloudflare zone](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
> - the domain's nameservers must be delegated to Cloudflare - and Workers have
> no stable IP for external DNS to point at. **The cutover is a nameserver
> move, not a record change.** That is a bigger operation and it puts the
> club's email records in the blast radius. See Phase 3.
>
> **2. The "three switches" are not three independent switches.** Deleting
> `MAIL_TEST_TO` is gated on Resend domain verification. Resend only delivers
> to the account owner's own address until a domain is verified, and
> `MAIL_FROM` is still Resend's shared test sender. Remove the test switch
> first and every enquiry 502s instead of reaching Melanie and Anna - a form
> that looks broken to the visitor and silently loses the enquiry. Resend must
> come first: Phase 2 before Phase 5.


> ## LIVE, BUT THE MEMBER PORTAL IS BROKEN - 21 September 2026, ~4pm ET
>
> `pinelakecc.com` and `www.pinelakecc.com` are serving the new site on valid
> certificates. Verified from outside: correct pages, no `X-Robots-Tag` on
> live, staging still `noindex` and `Disallow: /`, portal redirects firing.
>
> **But `members.pinelakecc.com` and `clubnow.pinelakecc.com` now return
> HTTP 403, Cloudflare `error code: 1014` - "CNAME Cross-User Banned".**
> Members cannot log in.
>
> This is a consequence of the migration, not a Northstar outage. Their
> service is up: `pinelakecc-com.northstar-connect.com` returns 200 directly.
> What broke is hostname authorisation. Both names are CNAMEs from our
> Cloudflare zone into Northstar's Cloudflare account, and Cloudflare blocks
> a cross-account CNAME unless the target account has that hostname
> registered through Cloudflare for SaaS. While `pinelakecc.com` was not a
> Cloudflare zone, this never came up. Now that it is one, it does.
>
> Timing: the portal returned 200 immediately after the nameserver switch and
> began returning 1014 after the zone went `active` and the Worker Custom
> Domains were attached.
>
> **TESTED AND DISPROVED, same evening:** the Worker Custom Domains were not
> the trigger. Both were removed, taking the website down, and the portal
> still returned 1014. They were re-added and the website restored. Do not
> repeat this test.
>
> What the timing points at instead is **zone activation**. The portal
> returned 200 while the Cloudflare zone was still `pending` and began
> failing once it went `active`. A pending zone is not authoritative, so
> Cloudflare does not yet enforce ownership of child hostnames. Once active,
> `members.pinelakecc.com` is a name Cloudflare knows belongs to this
> account, and a CNAME from it into another account is refused.
>
> That cannot be undone except by deleting the zone and reverting the
> nameservers, which would take the website down again, discard the whole
> migration and carry a 48-hour tail. Not worth doing.
>
> Two further workarounds were eliminated by measurement, not reasoning:
>
> - **Host-header proxy through our own Cloudflare.** Dead. The portal is
>   virtual-hosted on `members.pinelakecc.com` at Northstar's edge;
>   `pinelakecc-com.northstar-connect.com/web/pages/login` returns 404 and its
>   root serves the maintenance page. Overriding the Host proxies the wrong
>   site.
> - **Delegating `members` back to Network Solutions via NS records.** The
>   cross-user check reads Cloudflare's own account database rather than which
>   nameserver answered, and the request still arrives at their edge as
>   `members.pinelakecc.com`.
>
> **The fix is Northstar's.** Rizwan Rizvi, `support@globalnorthstar.com`,
> direct `rizwan.rizvi@globalnorthstar.com`, ticket #996907 is the thread.
> They need to add `members.pinelakecc.com` and `clubnow.pinelakecc.com` as
> **Custom Hostnames** in their Cloudflare for SaaS configuration. Now that
> the zone is ours, we can complete any DCV they ask for immediately -
> a `_acme-challenge.members` CNAME delegation or a TXT token, either is a
> two-minute change on our side.
>
> **Do not revert the nameservers for this.** The `.com` delegation carries a
> 48-hour TTL, it would take the new site down again, and the portal was
> already returning 1014 while the zone was live, so a revert is not a
> reliable undo.
>
> Untested but available if Northstar cannot move quickly: proxy `members`
> through our own Cloudflare with an Origin Rule overriding the Host header
> to `pinelakecc-com.northstar-connect.com`. **Try this only as a last
> resort** - Liferay sets `JSESSIONID` per host, so cookies and redirects may
> bind to the origin hostname and break login outright, which is worse than
> a clear error page.
## CUTOVER IN PROGRESS - nameservers moved, one step left

**Done, 21 September 2026 evening:**

- Cloudflare zone built and verified at **40 records**, matching the real zone
  at Network Solutions. See the warning block below - the inventory was wrong
  twice before it was right.
- **Nameservers switched** to `agustin.ns.cloudflare.com` and
  `paige.ns.cloudflare.com`. Delegation propagated within minutes and all 40
  records verify through public recursion on `1.1.1.1` and `8.8.8.8`.
- **Club email confirmed working in both directions** after the switch. This
  was the gate and it passed.
- `members.pinelakecc.com/web/pages/login` returns 200 on a valid certificate.
  Members were never locked out.
- **`main` pushed**, seven commits. The Worker is deployed and the hostname
  guard is confirmed working on staging.

**A bug was found and fixed during this, worth knowing about:**

`worker.js` was never running. A Worker with static assets does not invoke the
script for a request that matches an asset file, so the hostname guard was
dead code while `/api/inquiry` kept working and hid it. The result was the
staging URL serving an indexable `robots.txt` with no noindex header - exactly
what the guard existed to prevent. Fixed with `assets.run_worker_first: true`
in `wrangler.jsonc`, and verified against a real deploy rather than assumed.

**THE ONE REMAINING STEP - attach the Worker Custom Domains:**

Workers & Pages -> `pinelake-preview` -> **Domains** tab -> **Add Domain**.

1. Add `pinelakecc.com`. An apex `A` record to `104.24.9.63` still exists, so
   Cloudflare will warn about the conflict and offer to replace it. Accept.
2. Add `www.pinelakecc.com`. Same, against the `www` CNAME to `pinelakecc.com`.
3. Cloudflare issues the certificates itself, usually within a few minutes.

If Cloudflare refuses rather than offering to replace, delete those two
records first in DNS -> Records. Their current values are `104.24.9.63` and
`pinelakecc.com`, both DNS only, so they are trivially recreatable.

That is the last action. The moment it completes, the club has a website.
## Context for the record

> ### The inventory in this document was wrong, twice. Read this first.
>
> The real zone at Network Solutions holds **42 records**. Cloudflare's import
> scan found 22. Hand-probing the nameserver found 25. Neither was close.
>
> The gap was only found by opening the **Advanced DNS Records** panel at
> Network Solutions and reading the zone itself:
> Domains -> pinelakecc.com -> Advanced Tools -> Advanced DNS Records ->
> Manage. **That panel is the only authoritative source.** Nothing else -
> not a DNS query, not a provider's import scan - can tell you what a zone
> contains, because both can only report names they already know to ask for.
>
> Among the 15 records neither method found: the **Proofpoint DKIM signing
> key** for outbound club mail, **three Amazon SES DKIM CNAMEs**, and
> **`clubnow`**, a second live Northstar-hosted host alongside `members`.
> Switching the nameservers without them would have broken DKIM on the
> club's outbound email and taken a live host offline.


The Cloudflare zone is built but the nameservers have NOT moved. Nothing about
the live domain has changed yet.

**Cloudflare nameservers assigned:** `agustin.ns.cloudflare.com` and
`paige.ns.cloudflare.com`. Zone `pinelakecc.com`, Free plan, status `pending`.

Done in Cloudflare:

- Zone added, import scan run. **Bot Preference Sync was ON by default and was
  turned off** - it prepends Cloudflare's own directives to `robots.txt`, which
  would have fought the hostname guard in `worker.js`.
- All 22 imported records were imported **proxied**, which would have broken
  mail and both SendGrid DKIM keys. All 22 are now **DNS only**.
- Added `staging` A -> `64.135.45.138` and `*` A -> `64.135.11.57`, both of
  which the import scan missed.

- [x] `members` CNAME added by hand, confirmed live on Cloudflare.
- [x] `portal` resolved: **it has no record at all.** Nothing to migrate. The
      REFUSED answer to an A query was a Network Solutions quirk.

- [x] **The 15 missing records were imported** from
      `cutover-missing-records.zone` via Cloudflare DNS -> Records -> Import,
      with "Proxy imported records" left off. Cloudflare now holds 40.
- [x] **Verified against BOTH Cloudflare nameservers**, 40/40 each:

          .\dns-check.ps1 -Server agustin.ns.cloudflare.com
          .\dns-check.ps1 -Server paige.ns.cloudflare.com

      The Proofpoint DKIM TXT passes, so the 423-character key reassembled
      byte-exact from its two-chunk BIND split. Every CNAME returns its real
      target rather than a Cloudflare IP, which independently proves nothing
      was proxied on import.

**THE ZONE IS READY. The nameserver switch is the next action.**

At Network Solutions: Domains -> pinelakecc.com -> Advanced Tools ->
Nameservers (DNS) -> Manage. Replace `NS23.WORLDNIC.COM` and
`NS24.WORLDNIC.COM` with:

    agustin.ns.cloudflare.com
    paige.ns.cloudflare.com

**Change nothing else on that page.** Then confirm club email flows both
directions before going anywhere near the Worker - that is the gate, and it
is the reason the record work above mattered.

Then, in order: run `dns-check.ps1 -Server agustin.ns.cloudflare.com` and get
a clean pass, switch the nameservers at Network Solutions, confirm club email
still flows, delete the apex `A` and `www` `CNAME`, attach the Worker Custom
Domains, and push `main`.

---
## The order

The club has no website, so getting one back dominates everything else. The
forms still work today - they land in the club Gmail rather than reaching
Melanie and Anna - so mail routing is a degraded state, not an outage, and it
waits.

| # | Do | Why here |
|---|---|---|
| 1 | Build the zone in Cloudflare and check it (Phase 3, steps 1-5) | Changes nothing. Entirely safe, and it is where all the care goes. |
| 2 | Switch the nameservers (Phase 3, step 6) | The one irreversible-ish step. |
| 3 | Confirm club email still flows (Phase 3) | Before anything else. Stop here if it does not. |
| 4 | Attach the Worker Custom Domains (Phase 4) | |
| 5 | Push `main` (Phase 5, step 1) | **The club has a website again.** |
| 6 | Resend sending subdomain (Phase 2) | Easier in Cloudflare than at Network Solutions, and no longer on the critical path. |
| 7 | Remove `MAIL_TEST_TO` (Phase 5, step 2) | Only after step 6 verifies, or every enquiry 502s. |
| 8 | Search Console, tell members, the rest (Phase 6) | |

Phase 2 is numbered before Phase 3 because it was written when the old site
was still up and there was no hurry. Run it at step 6.

---
## What is actually there today

Checked against the authoritative nameservers and the live domain, not assumed.

| | |
|---|---|
| **Registrar & DNS** | Network Solutions (`ns23`/`ns24.worldnic.com`) - **the club controls this** |
| **Apex A** | `104.24.9.63` - a Cloudflare IP, but **Northstar's Cloudflare, not the club's** |
| **Apex TTL** | 1800s (30 min). Zone default TTL 3600s |
| **Member portal** | `members.pinelakecc.com` - Northstar-hosted, live, wildcard cert to 12 Nov 2026 |
| **Email** | Proofpoint inbound (`mx1`/`mx2-us1.ppe-hosted.com`) + Microsoft 365. **Nothing to do with the website.** |
| **New site** | Cloudflare **Worker** `pinelake-preview`, account `1902pinelakecc@gmail.com` |

**The club controls DNS, but not the Cloudflare layer in front of the old
site.** That Cloudflare account is Northstar's and fronts many club sites,
routing by hostname. Splitting traffic by path at that layer was never
available to us; it would have to be done by Northstar, inside their account.


## The member portal - RESOLVED 21 September 2026

Northstar moved the Liferay instance to **`members.pinelakecc.com`** under
ticket **#996907** (contact **Rizwan Rizvi**, `support@globalnorthstar.com`,
direct `rizwan.rizvi@globalnorthstar.com`). CNAME `members` ->
`pinelakecc-com.northstar-connect.com` is live at Network Solutions, covered by
the wildcard certificate (`*.pinelakecc.com`, Google Trust Services, expires
**12 Nov 2026**, Northstar's to renew).

**The member login URL is:**

    https://members.pinelakecc.com/web/pages/login

Rizwan asked for the root URL to be mapped to the login button. That is wrong
for a button labelled "Member Login": the root serves a portal **home** page
with no password field, which links onward to `/web/pages/login`. The deep link
is also the path members have used for years, so bookmarks carry over.

All 27 login links across 15 pages point at the deep link (done 21 Sept), and
the portal redirects in `_redirects` are now enabled.

---

## The DNS inventory

**Everything below must exist in Cloudflare, byte for byte, before the
nameservers change.** This is the whole risk of the cutover. Captured from
`ns23.worldnic.com` on 21 Sept 2026. Re-check it immediately before the move -
it is a snapshot, not a guarantee.

Cloudflare's scan on adding a zone imports most of this automatically. **Do not
trust the scan.** It regularly misses wildcards and records it cannot classify.

`dns-check.ps1` in this repo checks the whole table against any nameserver and
fails loudly on the mail records. Run it against Cloudflare before switching,
and against `ns23.worldnic.com` first to confirm this snapshot still matches
what is live:

    .\dns-check.ps1 -Server ns23.worldnic.com

It covers everything below except `portal`, which cannot be read over DNS.

### Apex

| Type | Name | Value | Proxy |
|---|---|---|---|
| A | `@` | `104.24.9.63` | **replaced by the Worker Custom Domain - do not recreate** |
| MX | `@` | `mx1-us1.ppe-hosted.com` (priority 10) | DNS only |
| MX | `@` | `mx2-us1.ppe-hosted.com` (priority 20) | DNS only |
| TXT | `@` | `v=spf1 a mx ip4:96.66.39.42 a:dispatch-us.ppe-hosted.com include:spf.protection.outlook.com include:sendgrid.net include:amazonses.com ~all` | - |
| TXT | `@` | `MS=ms21760240` (Microsoft 365 domain proof) | - |
| TXT | `@` | `ca3-76bea5dfdfb44e5fb535bcb237ce2fbb` | - |
| TXT | `@` | `ppe-dddb496a6869a2f3ac82b3b2d69d13928d3e9e21` (Proofpoint proof) | - |

### Subdomains

| Type | Name | Value | Proxy | Note |
|---|---|---|---|---|
| CNAME | `www` | `pinelakecc.com` | **replaced by the Worker Custom Domain** | see Phase 4 |
| CNAME | `members` | `pinelakecc-com.northstar-connect.com` | **DNS only** | proxying this breaks Northstar's host routing and their certificate |
| CNAME | `autodiscover` | `autodiscover.outlook.com` | DNS only | Microsoft 365 |
| CNAME | `sip` | `sipdir.online.lync.com` | DNS only | Microsoft 365 |
| CNAME | `lyncdiscover` | `webdir.online.lync.com` | DNS only | Microsoft 365 |
| CNAME | `enterpriseregistration` | `enterpriseregistration.windows.net` | DNS only | Microsoft 365 |
| CNAME | `enterpriseenrollment` | `enterpriseenrollment.manage.microsoft.com` | DNS only | Microsoft 365 |
| CNAME | `s1._domainkey` | `s1.domainkey.u4668611.wl112.sendgrid.net` | DNS only | **live SendGrid DKIM** |
| CNAME | `s2._domainkey` | `s2.domainkey.u4668611.wl112.sendgrid.net` | DNS only | **live SendGrid DKIM** |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc_rua@emaildefense.proofpoint.com; ruf=mailto:dmarc_ruf@emaildefense.proofpoint.com; fo=1` | - | Proofpoint reporting |
| A | `staging` | `64.135.45.138` | DNS only | **unidentified** - find out what this is before the move |
| ? | `portal` | **cannot be read over DNS** | ? | The name exists in the zone - the wildcard does not answer for it - but Network Solutions returns REFUSED for an A query. **Read it out of the control panel by eye before the move.** |
| A | `*` | `64.135.11.57` | **DNS only** | old 365 Datacenters host, nothing known uses it. A proxied wildcard needs Enterprise, so keep it grey |

`selector1`/`selector2._domainkey` are **absent** - Microsoft 365 DKIM signing
is not configured. That is the state today; do not "fix" it during a cutover.

### SPF - why it is at 7 of 10

The limit is 10 DNS-lookup mechanisms, nested ones included. Counted live:

| Mechanism | Lookups |
|---|---|
| `a` | 1 |
| `mx` | 1 |
| `a:dispatch-us.ppe-hosted.com` | 1 |
| `include:spf.protection.outlook.com` | 1 (no nested includes) |
| `include:sendgrid.net` | 2 (it nests `include:ab.sendgrid.net`) |
| `include:amazonses.com` | 1 (no nested includes) |
| **Total** | **7** |

SendGrid has live DKIM keys, so something is actively sending through it.
**Do not remove includes to make room.** Check Proofpoint's DMARC reports
first - the `rua` address above is where they go.

**Phase 2 avoids this record entirely.** Do not add a Resend include here.

---

## Phase 1 - Code preparation - DONE 21 Sept 2026

No DNS, no risk, all committed and held unpushed until the cutover window.

- [x] **Member login links** - all 27 across 15 pages repointed to
      `https://members.pinelakecc.com/web/pages/login`.
- [x] **Portal redirects enabled** in `_redirects` (`/login`, `/web/*`, `/c/*`,
      `/documents/*`, `/o/*`). Static `/login` above the splats, splats last.
- [x] **Indexing switched from a manual flip to a hostname guard.** The
      `X-Robots-Tag` block is out of `_headers` and `robots.txt` now allows
      crawling. `worker.js` adds `noindex, nofollow` and serves a
      `Disallow: /` robots.txt for **any hostname that is not**
      `pinelakecc.com` or `www.pinelakecc.com`.

      This replaces two of the three launch switches. One deployment serves
      both the staging `.workers.dev` URL and the live domain, so a blanket
      rule cannot be right for both: leave it on and the real site never
      ranks; take it off and staging gets indexed as duplicate content against
      the club's own pages. Guarding by hostname is correct in both places at
      once and there is nothing left to remember. Same approach as the GA4
      guard already in the page head.
- [x] **Canonicals** on all 14 pages, self-referential to `https://pinelakecc.com/...`.
- [x] **`sitemap.xml`** already lists the 14 live-domain URLs.
- [x] **404 page**, form endpoint, GA4 - all done and tested.

Still open from the original Phase 1, and **not blocking the cutover**:

| Page | Decision |
|---|---|
| Privacy Policy | Exists at `/privacy`. **Not legally reviewed** - recorded as a known risk the client is not pursuing. |
| Employment | `/employment` -> `/contact`. `/employment-application` has nowhere to land. |
| Scholarship Foundation | No home. Will 404. |
| Mobile Application | No home. Will 404. |
| Christmas Fund Form | No home. Will 404. |
| Caddie Program | `/caddie-program` -> `/golf`, which does not cover it. Accepted loss. |
| Guest Information | `/guest-information` -> `/about`. |
| Staff | `/staff` -> `/contact`, as the committee chose. |
| Picture Gallery | `/picture-gallery` -> `/about` until the enhancement lands. |

Those four 404s are a known, accepted gap. They can be redirected at any time
after launch without another cutover.

---

## Phase 2 - Resend sending domain (step 6 - after the site is back up)

The forms work today, but only into the club Gmail, because `MAIL_FROM` is
Resend's shared test sender. To reach Melanie and Anna the club needs a
verified sending domain. **This is step 6 in the order above** - it is not on
the critical path to getting the site back, and it is easier to do once the
zone is in Cloudflare.

**Verify a subdomain, not the apex.** Resend
[recommends a subdomain](https://resend.com/docs/dashboard/domains/introduction)
for sending-reputation isolation, and here it also solves the SPF problem: the
SPF and DKIM records Resend asks for land on the subdomain's own records, and
**the apex SPF record is never touched.** No headroom needed, no risk to the
club's live email. Use something like `send.pinelakecc.com`.

1. Add `send.pinelakecc.com` as a domain in Resend.
2. Create the records Resend shows - they will be an MX, a TXT SPF and a DKIM
   TXT, **all on `send.pinelakecc.com`**. Add them at whichever provider is
   authoritative at the time. Before Phase 3 that is Network Solutions; after,
   Cloudflare. Either is fine, but do it in one place.
3. Wait for Resend to report the domain verified.
4. Change `MAIL_FROM` in `wrangler.jsonc` to a club address on that subdomain,
   for example `Pine Lake Website <forms@send.pinelakecc.com>`.
5. **Test with `MAIL_TEST_TO` still set.** Confirm a submission arrives.
6. Only then remove `MAIL_TEST_TO` (Phase 5) and send one more test that
   genuinely reaches Melanie and Anna.

> **Network Solutions' DNS form is mislabelled.** "Refers to" is the name you
> are creating; "Alias to" is the destination. That is backwards from how the
> words read and it has already produced one broken record.

---

## Phase 3 - Move the zone to Cloudflare

This is the cutover. It is a **nameserver delegation change**, and unlike an A
record it does not roll back quickly: the `.com` registry publishes the
delegation with a 48-hour TTL. Get the records right before you switch, not
after.

Nothing about the website is at stake here - it is already down. **Email is.**

1. In the club's Cloudflare account (`1902pinelakecc@gmail.com`), **Add a
   site**, `pinelakecc.com`, Free plan. Let it scan.
2. **Reconcile the imported records against the inventory above, line by
   line.** Add what the scan missed. Pay particular attention to the wildcard
   `*`, the two SendGrid DKIM CNAMEs and all four apex TXT records.
3. Set **`members`, and every mail-related record, to DNS only (grey cloud).**
   Proxying `members` breaks Northstar's routing and certificate.
4. Delete nothing from Network Solutions yet. Both sets stay live through the
   handover, which is exactly why they have to match.
5. **Before switching:** re-run the inventory check against Cloudflare's
   nameservers directly, so you are reading Cloudflare's answers rather than a
   cached one. Compare MX, all four apex TXT records, `_dmarc` and both
   `_domainkey` CNAMEs against the table above.
6. At Network Solutions, change the nameservers to the two Cloudflare gives
   you. **Do not touch anything else while you are in there** - the commonest
   way a domain move breaks a business is someone tidying up DNS in passing.
7. The registry updates within an hour or so; resolvers holding the old
   delegation can take up to 48. Both sides answer identically, so this is
   invisible as long as step 2 was done properly.

### Verify email survived, before anything else

- [ ] Send a message **to** a club address from outside and confirm delivery
- [ ] Send a message **from** a club address and confirm it arrives unflagged
- [ ] `nslookup -type=MX pinelakecc.com` against Cloudflare's nameservers
      returns both Proofpoint hosts
- [ ] `nslookup -type=TXT pinelakecc.com` returns **all four** apex TXT records
- [ ] `members.pinelakecc.com/web/pages/login` still loads with a valid cert

**Do not proceed to Phase 4 until email is confirmed working.**

---

## Phase 4 - Attach the Worker

Once the zone is active in Cloudflare:

1. Worker `pinelake-preview` -> **Settings -> Domains & Routes -> Add Custom
   Domain**. Add `pinelakecc.com`.
2. Add `www.pinelakecc.com` the same way. Cloudflare creates the proxied DNS
   records and issues the certificate itself - there is no IP to enter, which
   is the whole reason the old A-record plan could not work.
3. Remove the leftover apex `A` and `www` `CNAME` if the scan recreated them.
   A Custom Domain cannot sit on a hostname that already has a CNAME.
4. Canonicals on every page point at the apex, so `www` serving the same
   content is safe. Optionally add a Cloudflare redirect rule sending `www` to
   the apex - a tidiness improvement, not a launch requirement.
5. Certificate issuance is usually a few minutes. Confirm a valid certificate
   on both hostnames before telling anyone.

---

## Phase 5 - Take the site live

1. **Push `main`.** This deploys the held commits. Once DNS resolves to the
   Worker, `pinelakecc.com` is indexable automatically - the hostname guard in
   `worker.js` needs no switch thrown.
2. Remove `MAIL_TEST_TO` from `wrangler.jsonc` and push. **Only if Phase 2 is
   verified complete.**

### Verify, in this order

- [ ] `https://pinelakecc.com` and `https://www.pinelakecc.com` both load the new site
- [ ] Certificate valid on both, no browser warning
- [ ] `curl -sI https://pinelakecc.com/ | grep -i x-robots-tag` returns **nothing**
- [ ] `https://pinelakecc.com/robots.txt` says `Allow: /`
- [ ] The staging `.workers.dev` URL **still** returns `X-Robots-Tag: noindex`
      and a `Disallow: /` robots.txt
- [ ] A member can log in at `members.pinelakecc.com/web/pages/login`
- [ ] `pinelakecc.com/web/pages/login` redirects to the portal
- [ ] `pinelakecc.com/login` redirects to the portal
- [ ] Spot-check ten old URLs from the redirect map
- [ ] Submit a form and confirm it arrives at the club, not the test inbox
- [ ] GA4 realtime shows the visit
- [ ] Check on an actual phone, not a resized browser

### If it goes wrong

**The website:** the Worker is the only thing serving the domain, so a bad
deploy is fixed by a revert and a push - a minute or two, no DNS involved.

**The nameservers:** switching them back at Network Solutions works but is
slow, up to 48 hours, and pointless for the site - the old site is gone either
way. The only reason to do it would be an email problem, which is exactly why
Phase 3 verifies email before Phase 4 begins.

---

## Phase 6 - The first fortnight

- [ ] **Google Search Console**: add the property, submit
      `https://pinelakecc.com/sitemap.xml`. Expect ranking movement for a few
      weeks - normal after a site change, and it settles.
- [ ] Request indexing for the main pages. The site has been `noindex` and the
      old URLs have been 404ing, so Google needs prompting.
- [ ] Watch the **Coverage** report for 404s. Any old URL missed from the
      redirect map shows up here; add a redirect.
- [ ] **Tell members** the portal moved to
      `members.pinelakecc.com/web/pages/login`. They will be logged out once -
      `JSESSIONID` is host-only.
- [ ] **Register the GA4 custom dimensions** `inquiry_type` and `routed_to`,
      or those parameters never appear in reports.
- [ ] Update the **Google Business Profile** link.
- [ ] Update the link in the **Instagram, TikTok and Facebook** bios.
- [ ] Identify and clean up `staging` and `portal` if they turn out to be dead.
- [ ] Have Northstar confirm what is still being billed.
- [ ] **Back up `../old-site-archive-2026-09-21/` off this machine.** It is the
      only copy of the old site that exists and it is not in git.

---

## Redirect map (reference)

> This is the original inventory of old URLs, kept as a record of what each
> one maps to. The live rules are in `_redirects`, in Cloudflare format and
> Cloudflare order - static before dynamic, the opposite of Vercel. Treat what
> follows as content, not as instructions.

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

---

## Member portal 1014 — what is actually known, 21 Sept 2026 evening

Recorded because two earlier explanations in this document were wrong and a
cold session should not re-run the dead ends.

**Measured facts:**

| Check | Result |
|---|---|
| `members` / `clubnow` | HTTP 403, Cloudflare `error code: 1014`, from Northstar's edge |
| Our DNS for both | Correct, unproxied, CNAME to `pinelakecc-com.northstar-connect.com` |
| Northstar's certificate on `members` | CN `pinelakecc.com`, SAN `pinelakecc.com` + `*.pinelakecc.com`, Google Trust Services, **reissued 21 Sept 19:17 UTC** |
| TLS handshake | Succeeds. The failure is at HTTP routing, after the handshake |
| Zone hold on our zone | **Off.** `hold: false, include_subdomains: false` |
| `_cf-custom-hostname.pinelakecc.com` | Present: `cee63117-fc80-457c-acde-bbb9fef59b3d` |
| `_cf-custom-hostname.members` / `.clubnow` | **Absent** |
| `pinelakecc-com.northstar-connect.com/` | 200, "Site is Under Maintenance" |
| `pinelakecc-com.northstar-connect.com/web/pages/login` | 404 — the portal is virtual-hosted on `members.pinelakecc.com` |

**So Northstar's Cloudflare for SaaS setup is working** - a wildcard custom
hostname exists and its certificate was reissued today. The hostnames were
never "unregistered"; an earlier draft of the escalation said so and was
wrong.

**Most likely cause, not proven:** now that `pinelakecc.com` is an active
Cloudflare zone in a different account, Cloudflare requires hostname
ownership verification for custom hostnames on it and blocks them until the
`_cf-custom-hostname.<hostname>` TXT is present. The apex has one. The two
failing hostnames do not.

**The ask, which holds even if that diagnosis is imperfect:** Northstar sends
the `ownership_verification` TXT values for `members.pinelakecc.com` and
`clubnow.pinelakecc.com`; we publish them in minutes because the zone is ours.

**Tested and closed - do not repeat:** removing the Worker Custom Domains
(disproved, website went down, portal still 1014), Host-header proxy (dead,
their hostname 404s the portal), NS delegation of the subdomain, and the zone
hold theory (hold is off).
