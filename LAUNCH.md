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

**Tested later the same evening — Orange-to-Orange.** The `members` CNAME was
set to Proxied. DNS confirmed resolving to our Cloudflare (`104.21.34.13`,
`172.67.167.176`) rather than Northstar's, so O2O engaged and Cloudflare
routed our zone -> their zone. **Still 1014.** With both zones visible to
Cloudflare it will not honour a custom hostname for `members` in Northstar's
account, which means their custom hostname is not in an active state. That is
the strongest evidence so far that the block is on their side. Record
reverted to DNS only so their fix lands on the configuration that worked
before. Live site unaffected throughout.

Remaining untested lever: delegating `members` out of the zone with NS records
to `ns23`/`ns24.worldnic.com` (which still hold the CNAME). Low odds — the
cross-user decision appears to key off zone ownership, not the DNS path — but
cheap and reversible.

**21 Sept, ~6pm ET - Northstar replied and their records are in.** Eleazer
Noman (Northstar) asked for: A `members` -> `104.24.9.63`, TXT
`_cf-custom-hostname.members` -> `8b03768f-10a5-4e60-990b-50fd22c1effc`, CNAME
`_acme-challenge.members` -> `members.pinelakecc.com.911c093aa0273216.dcv.cloudflare.com`.
All three added (the old `members` CNAME deleted first, since a CNAME cannot
coexist with an A) and verified on both Cloudflare nameservers and via
`1.1.1.1`. Zone is at 42 records.

The portal error changed from 1014 to **1000 "DNS points to prohibited IP"**.
That is expected: the cross-account CNAME is gone, so 1014 cannot fire; what
remains is that the custom hostname is not yet active in Northstar's account.
Northstar said they would "proceed with the setup" once the records were in
place. Waiting on them. Nothing further to do on our side.

Their fourth requested record, `CNAME clubnow.members ->
member-pinelakecc-com.northstar-connect.com`, was NOT applied: the target does
not resolve and the name would create a third-level hostname nothing uses.
Queried back as a probable typo. `clubnow` still returns 1014 and still has no
verification records; if it matters, Northstar needs to send its set too.
**Double-checked, same evening, that nothing remains on our side.** Verified,
not reasoned: `members` carries exactly one record (A `104.24.9.63`), no stray
AAAA, no leftover CNAME, DNS-only (our own edge IPs appear nowhere), and the
`_cf-custom-hostname.members` token is byte-exact on `1.1.1.1`, `8.8.8.8` and
`9.9.9.9`. Cloudflare's error-1000 documentation lists our exact case as cause
8 - "DNS record points to a SaaS provider using Cloudflare for SaaS ... if the
provider has not configured a custom hostname for your domain, this error is
returned" - with the resolution "contact the SaaS provider ... The error
originates from the provider's Cloudflare account, not yours."

If it still shows error 1000 after Northstar says they have activated the
hostname, the one thing to try on our side is swapping the A record back to
the original CNAME (`pinelakecc-com.northstar-connect.com`, DNS only) in case
`104.24.9.63` is not the edge their SaaS zone uses. One-minute change.

**21 Sept, ~7pm ET - Northstar says "complete, waiting on propagation". It is
not propagation. Two measured facts:**

1. **Their A-record instruction is the wrong shape.** Cloudflare's error-1000
   documentation, cause 1: "An A record within your Cloudflare DNS app points
   to a Cloudflare IP address." That is exactly `members A -> 104.24.9.63`
   from inside our zone. `104.24.9.63` is the edge serving
   `www.globalnorthstar.com`, Northstar's own website. Forcing the connection
   to their SaaS zone's edge IPs (`104.18.28.51` / `.29.51`) with `--resolve`
   gives the identical error, so the ingress IP is not the variable - the
   trigger is our zone holding an A record to any Cloudflare IP. This cannot
   work as instructed. The supported shape is a CNAME to the provider's target.
   I applied their instruction without checking it against this doc; that was
   a mistake and it cost a round trip.

2. **The CNAME target they have used for years no longer resolves.**
   `pinelakecc-com.northstar-connect.com` returned `104.18.28.51 / .29.51` at
   ~5pm and returns NODATA at ~7pm, from both public resolvers and their own
   authoritative nameservers (`josh` / `bella.ns.cloudflare.com`). Something in
   their "configurations complete" step removed or renamed it. Until they give
   a target that resolves, switching back to a CNAME would fail differently
   (no address at all) rather than fix anything.

What IS working: the custom hostname on their side is validated - Cloudflare
issued a per-hostname certificate `CN=members.pinelakecc.com` at 21:10 UTC,
which only happens after ownership verification succeeds. Our TXT and DCV
records did their job.

**Propagation is not a factor.** All six public resolvers tested (Cloudflare,
Google, Quad9, OpenDNS, Verisign, Level3) return the new A record and both
verification records. Cloudflare's own verification reads authoritative DNS.

**Next action is Northstar's, and it is specific:** provide the CNAME target
for the `members.pinelakecc.com` custom hostname (the "CNAME target" shown
on their Custom Hostnames page / their fallback-origin hostname) and confirm
it resolves. Then we replace the A record with that CNAME, DNS only - a
one-minute change - and test.

**21 Sept, ~7:30pm ET - every configuration of the `members` record has now
been tested. Results, all with Northstar's ownership TXT and DCV in place and
their per-hostname certificate (`CN=members.pinelakecc.com`, 21:10 UTC) issued:**

| Our `members` record | Result |
|---|---|
| A -> `104.24.9.63`, DNS only (Northstar's instruction) | **error 1000** "DNS points to prohibited IP" - Cloudflare's documented cause 1; A records to the SaaS target are "not a supported setup" |
| CNAME -> `customers.northstar-connect.com`, DNS only (**current**) | **error 1014** |
| CNAME -> `pinelakecc-com.northstar-connect.com`, proxied (O2O) | error 1014 (tested earlier; that target no longer resolves at all) |

`customers.northstar-connect.com` is the name Cloudflare's own SaaS guide uses
as the example CNAME target, it lives in Northstar's SaaS zone, and it resolves
to the same edge pair the old target did. Our side is now in the documented
shape end to end. The remaining 1014, with their certificate already issued,
is the signature of a custom hostname whose `ssl.status` is active but whose
**hostname `status` is still Pending** (Cloudflare: "Hostname validation and
certificate validation use different tokens and API fields").

**What clears it, per Cloudflare's docs:** Cloudflare retries hostname
validation on a backoff - "the first 10 checks complete within 20 minutes and
most checks complete in the first four hours" - or the provider forces it:
"Select **Refresh** on the dashboard" (Custom Hostnames page) or `PATCH` the
custom hostname via API. If the hostname shows **Moved**, it is because it
"no longer points to the fallback origin"; Refresh "will set the custom
hostname back to Pending validation".

**Side effect to raise with Northstar:** `clubnow.pinelakecc.com` now fails to
connect at all (HTTP 000), because its CNAME target
`pinelakecc-com.northstar-connect.com` stopped resolving on their side this
evening. Not something we changed. Needs the same treatment as `members` if
the club uses it.

---

## RESOLVED - 21 September 2026, ~9:25pm ET

**The member portal and mobile app are back.** `members.pinelakecc.com/web/pages/login`
returns 200 with the real login form on Northstar's per-hostname certificate,
verified from outside. Website 200. `/login` and `/web/pages/login` on the
apex 301 to the portal. Members will have been logged out once (`JSESSIONID`
is host-only) and simply sign in again; no data was ever at risk - the
requests never reached Northstar's servers while it was down.

**What fixed it, in order:**

1. Northstar sent an ownership token (`_cf-custom-hostname.members` TXT) and a
   DCV delegation (`_acme-challenge.members` CNAME). Both published; their
   certificate for `members.pinelakecc.com` issued at 21:10 UTC.
2. Their instruction to use an A record to `104.24.9.63` was replaced with a
   CNAME to `customers.northstar-connect.com`, their live SaaS target - the A
   record is a documented-unsupported shape and produced error 1000.
3. Northstar activated the custom hostname on their side. The portal returned
   200 within minutes of their 9:25pm message.

**Final DNS shape for the portal (all DNS only):**

    members                   CNAME  customers.northstar-connect.com
    _cf-custom-hostname.members  TXT  8b03768f-10a5-4e60-990b-50fd22c1effc
    _acme-challenge.members   CNAME  members.pinelakecc.com.911c093aa0273216.dcv.cloudflare.com
    clubnow.members           CNAME  members-pinelakecc-com.northstar-connect.com

`clubnow.pinelakecc.com` no longer exists. Northstar renamed it to
`clubnow.members.pinelakecc.com` so their `*.members.pinelakecc.com`
certificate covers it; the old record's target had stopped resolving on their
side. It currently serves their "Under Maintenance" page - whatever ClubNow is,
that is theirs to populate.

**Root cause, for the record:** moving `pinelakecc.com` onto Cloudflare made
it an active zone in the club's account. Cloudflare then refused to route
`members.pinelakecc.com` - a name in that zone - into Northstar's Cloudflare
account until Northstar's custom hostname for it was ownership-verified and
active. It had never needed to be, because the domain had never been on
Cloudflare before. This was foreseeable from two facts known before the switch
(the `members` CNAME resolved to Cloudflare IPs; we were moving to Cloudflare)
and should have been raised with Northstar beforehand. It is now in HANDOFF.md
as a trap.

---

## 21 September, ~9:50pm ET - the ClubNow MOBILE APP broke when clubnow was renamed

Members reported the app "loading indefinitely", not loading, or demanding a
fresh sign-in. Measured cause: **`clubnow.pinelakecc.com` is the ClubNow app's
backend hostname** (ClubNow is Northstar's member app -
globalnorthstar.com/club-now). At Northstar's written instruction the
`clubnow` CNAME was deleted and replaced with `clubnow.members.pinelakecc.com`.
The old name then fell to the zone's `*` wildcard, `64.135.11.57`, a dead
host: TCP to it hangs and HTTPS times out. That is an app spinner.

The renamed `clubnow.members.pinelakecc.com` reaches Northstar's edge but
serves their "Site is Under Maintenance" page and 404s every app path - the
backend is not configured there. So the rename broke the app on both ends: the
old name went dark and the new one has nothing behind it.

**Restored on our side:** `clubnow` CNAME -> `members-pinelakecc-com.northstar-connect.com`,
DNS only. It now reaches their edge in ~0.1s and returns **1014** - a fast
fail instead of a hang - because their account no longer holds an active
custom hostname for `clubnow.pinelakecc.com`. That is the piece only Northstar
can restore: re-add / re-activate `clubnow.pinelakecc.com` as a custom
hostname (it worked that way until this evening), OR ship the app pointing at
`clubnow.members.pinelakecc.com` AND stand the backend up there. Both
`clubnow` records are left in place so either path works without more DNS.

The "sign in again, saved login gone" reports are a separate, expected effect:
sessions were invalidated by the outage and app credential storage is keyed to
the backend host, which Northstar changed today. Not DNS; not ours.

---

## 22 September, ~11:20am ET - the ClubNow app is BACK, and the clubnow theory was wrong

Members report the app working. Measured at the same moment:
`clubnow.pinelakecc.com` still returns Cloudflare **1014**, unchanged since last
night. **The app therefore does not depend on `clubnow.pinelakecc.com`.** The
attribution written into this file last night was an inference from the
product name and the timing, and it was wrong. The app talks to
`members.pinelakecc.com` - the same host as the portal - so it went down with
the portal and came back with it; the stragglers overnight were phones and
carrier resolvers holding last night's bad answers until their caches expired.

What that means for the record: removing and restoring `clubnow` had no effect
on members either way. `clubnow.pinelakecc.com` and `clubnow.members.pinelakecc.com`
are both left in place, both reaching Northstar's edge (`clubnow.members` now
hits a Tomcat 404 rather than the maintenance placeholder, so they are working
on it). What `clubnow` is actually for is a question for Northstar, not an
outage. dns-check.ps1 downgrades it to INFO.

Also noted for the next reader: around 11:15am ET every *direct* DNS query
from this PC to external nameservers (Cloudflare's, `1.1.1.1`, `8.8.8.8`)
timed out, including for `cloudflare.com` and `google.com`, while the system
resolver and HTTPS worked normally. That is a local firewall/VPN state on this
machine, not a record problem. If `dns-check.ps1` suddenly fails everything,
test a neutral name first.

**Final state, all verified from outside:** website up, member portal up,
mobile app up, email untouched throughout. Total member-facing outage: portal
~5 hours, app ~14 hours, both on 21-22 Sept 2026, both caused by the domain
moving onto Cloudflare while `members.pinelakecc.com` CNAMEd into Northstar's
Cloudflare account - HANDOFF.md trap 7.

---

## What `clubnow.pinelakecc.com` is - everything learnable without asking Northstar (22 Sept, midday)

Gathered so a question to Northstar can be one line, or skipped.

| Evidence | Source | What it shows |
|---|---|---|
| The old website (193 files, 4,726 links to `pinelakecc.com`) never once linked to `clubnow.` - or to **any** `*.pinelakecc.com` subdomain | grep of `old-site-archive-2026-09-21` | The club's own site never used it. It is Northstar-internal. |
| Every old page carries `Liferay.ThemeDisplay.isClubNow: function() { return "false"; }` | same archive, Northstar's Liferay theme | The **ClubNow app renders the member portal's own pages** in a web view, with this server-side flag telling the theme it is inside the app. The app therefore uses the **portal host**. |
| The app came back for members while `clubnow.pinelakecc.com` still returned 1014 | live, 22 Sept ~11am | Proof the app does not depend on `clubnow.`. |
| No certificate in the public CT logs has **ever** explicitly named `clubnow.pinelakecc.com`; it was only ever covered by Northstar's `*.pinelakecc.com` wildcard | crt.sh | It was never a first-class custom hostname - it rode the wildcard, which is exactly why it broke when per-hostname verification became required. |
| No Wayback Machine snapshot of it, ever | archive.org | Nothing public was ever served there. |
| `northstar.pinelakecc.com` -> `96.66.39.41`, non-Cloudflare, once had its own Sectigo certs (the four `_xxx.northstar` DCV CNAMEs) | CT logs + live probe | **Dark.** Nothing on 80/443/8443/8080. Almost certainly the club's retired on-premises Northstar server (the SPF's `ip4:96.66.39.42` is the adjacent address at the same site). Not the app. |
| crt.sh currently shows nothing for `members.pinelakecc.com` either, yet the live cert is `CN=members.pinelakecc.com`, GTS WE1, serial `F2BA931D634FE4550EEDA618615099B7`, issued 21 Sept 21:10 UTC | openssl vs crt.sh | crt.sh is lagging ~24h; treat its "no cert" answers for recent names as unknown, not absent. |

**Best reading:** `clubnow.pinelakecc.com` is a Northstar-side alias - a per-club
hostname their platform provisions by convention, riding the wildcard cert, that
nothing at Pine Lake actually calls. Members never noticed it break because
nothing depends on it. `clubnow.members.pinelakecc.com` is Northstar's attempt
to re-home that alias under the verified `members` hostname; it now reaches a
Tomcat 404 rather than a placeholder, so someone there is working on it, and it
is equally unused by members.

**Consequence:** no outage is open. The only question worth Northstar's time is
housekeeping - whether either `clubnow` name should exist at all - and it can
wait for the next scheduled contact rather than a ticket.

---

## Post-launch QA - 22 September 2026, midday

Full sweep of the live site from outside: 14 pages, 54 internal and 22 external
links, all 55 redirect rules, the form end to end (API and a real browser
submission through the runtime), private-file exposure, indexing on live vs
staging, console errors, phone-width render, headers, asset weights,
accessibility basics. Everything passed except the items below.

**Fixed and verified live the same day (commit 3e03c28):**

1. **Wrong confirmation after a successful send.** The API accepted the note
   but the page showed the email-app fallback wording ("Almost there... your
   note is open in your email app, press send"). One `submitted` flag, one
   panel, fallback copy. Now two panels keyed on which path completed:
   "Thank you - your note is on its way. A member of our team will reach out
   personally." for the API, the old wording for the mailto fallback. All 12
   form pages; each page's own styling preserved. Proven by a real runtime
   submission on the deployed build: POST 200, correct panel shown.
2. **HTTP served the site unencrypted.** `worker.js` now 301s http to https
   before anything else. Verified on apex and www.
3. **No `lang` on any page.** All 15 served pages carry `lang="en"`.
4. **No security headers.** `_headers` now sets X-Content-Type-Options,
   X-Frame-Options, Referrer-Policy and 180-day HSTS (no includeSubDomains -
   the subdomains are Northstar's). Verified on pages and images.

**Still open, in priority order:**

- **Hero video ignores byte-range requests.** Every `Range:` request gets the
  full 7.2 MB as a 200 with no Content-Range. Chrome fetched it four times on
  one homepage load; iOS Safari generally will not play video at all without
  206 support and shows the poster instead. HANDOFF.md warned of exactly this.
  Likely cause: `run_worker_first: true` sends every asset through
  `env.ASSETS.fetch`, which does not appear to pass ranges through. Proposed
  fix: narrow `run_worker_first` to HTML routes and `/robots.txt` so images and
  video are served natively - then re-test with `curl -H "Range: bytes=0-1023"`
  expecting 206, and on a real iPhone.
- **Free-plan request cliff.** With `run_worker_first: true` every request
  counts against the Workers Free limit of 100,000/day, and over it requests
  return 429 rather than falling back to static serving. Measured 12,224
  requests in the 24h around launch (~12%). Same fix as above removes most of
  the exposure. Otherwise the Workers Paid plan is the answer.
- **Homepage weighs 11.2 MB**, 7.2 MB of it the video, loaded unconditionally
  on every device. None of the 113 images use `loading="lazy"`. Proposed:
  lazy-load below-the-fold images; do not load the video under ~768px (the
  poster is already there).
- **Nice-to-haves:** `www` serves rather than redirecting to the apex
  (canonicals make it harmless); paths are case-sensitive (`/Golf` 404s);
  form fields have no `required` attributes so validation feedback is
  server-side only; 32 images carry empty `alt=""` - fine if decorative.
- **Still deliberately on:** `MAIL_TEST_TO`. Three `[TEST]` QA submissions
  and one more from the runtime test are in the club Gmail as evidence the
  delivery path works.

**22 Sept, afternoon - byte-range / request-cap fix shipped (commit follows).**
`run_worker_first` changed from `true` to `["/*", "!/img/*"]`. Pages,
`robots.txt` and `/api/*` still run through `worker.js` (hostname guard,
http->https, `_redirects`); `/img/*` is served natively by the asset server so
the hero video can answer Range requests with 206 and image requests stop
counting against the Workers Free 100k/day cap. `_headers` still applies to
natively served assets. Side effect, accepted: images on the staging host no
longer carry `X-Robots-Tag` (pages still do), and a plain-http request for an
image is not redirected by the Worker - HSTS and the page-level redirect make
that moot in practice, and the zone toggle "Always Use HTTPS" closes it fully.
Verification below.

**Verification of the previous entry, and what it turned into.** With `/img/*`
excluded from the Worker, the hero video STILL answered every Range request
with a 200 and the whole file - and so did every image and `support.js`, with
no `Accept-Ranges` header, cache-busted and mid-file. Cloudflare's static asset
server does not support byte ranges at all; the Worker was never the cause.
The exclusion is kept for the request-cap benefit, narrowed to image types so
`.mp4` reaches the Worker, and `worker.js` now serves single-range 206
responses for video itself: `bytes=a-b`, `bytes=a-`, `bytes=-n`, clamped ends,
416 when unsatisfiable, HEAD, `Accept-Ranges` advertised on the plain GET.
Slices are streamed through a TransformStream, not buffered. Tested in a
browser JS engine against a fake asset streamed in 300-byte chunks: 12 of 12
checks byte-exact before the deploy.
