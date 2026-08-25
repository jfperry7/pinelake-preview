# Pine Lake website — enhancements after launch

Everything here is deliberately deferred. None of it blocks the site going
live, and none of it is waiting on design or development time — each item is
waiting on an input the club has to supply. This lists what each one is, why
it is not in the current build, and exactly what is needed to do it properly.

---

## 1. "Meet the Pro" on Tennis and Golf

**The ask.** The Dining page has a Chef Patrick block — photo, name, a few
lines on his background. Tennis and Golf have nothing equivalent. We sell
three departments the same way, but only one of them currently has a face on
it.

**What we need**
- A headshot of Peter Necajevs and one of Chris Lawson. Shoulders-up, shot
  outdoors on court and on course respectively, not a posed studio portrait —
  it should match the way Chef Patrick is photographed.
- Three or four lines each: where they came from, how long they have been at
  Pine Lake, what they are known for, one specific thing a member would
  recognise. Their own words are better than a bio we write for them.
- Confirmation of exact titles.

**Effort once we have it.** Half a day. The layout already exists on the
Dining page; we would reuse it.

---

## 2. Events and wedding gallery

**The ask.** A Gallery button under Events that opens a set of wedding and
club-event photos. The reasoning is sound — a couple touring venues will not
inquire off copy alone, they need to see the rooms dressed.

**Why it is not built.** There is not one wedding photograph in the club's
asset library. I searched all 4,243 files: no tented lawn, no head table, no
ceremony, no reception. A gallery button today would open onto an empty room,
which is worse than not having one.

**What we need**, in order of preference:
1. Photograph the next wedding on property. One photographer, full day,
   with a shot list agreed in advance — rooms before guests arrive, tables
   set, ceremony, reception, the lake at golden hour. This is the only
   option that produces images we control outright.
2. Ask two or three past couples for permission to use their photographer's
   images. Needs written release from both the couple and the photographer,
   since the photographer holds the copyright. Slower and the coverage will
   be uneven, but it costs nothing.
3. A styled shoot — tables set, florals, no guests. Cheapest and fastest,
   and useful for showing the rooms, but it will not carry the atmosphere
   that sells a wedding.

**Effort once we have it.** One to two days for a proper lightbox gallery.

---

## 3. Form delivery

**Where it stands.** Every form on the site is wired to open the sender's
email client, pre-addressed and pre-filled — membership inquiries to Melanie,
event and wedding inquiries to Anna. That works everywhere and needed no
third-party account, but it depends on the visitor having a mail client
configured, and it gives us no record of submissions.

**What we need.** The endpoint URL from the Formspree account. It is on the
form's page in the Formspree dashboard and looks like
`https://formspree.io/f/xxxxxxxx`. Two endpoints would be better than one —
membership and events — so the two inboxes stay separate.

**Effort once we have it.** An hour, all 13 pages.

---

## 4. Analytics

**What we need.** A GA4 Measurement ID (`G-XXXXXXXXXX`) from the club's
Google Analytics property. If the club does not have one, it takes about ten
minutes to create.

Worth deciding at the same time: whether to track form submissions and
"Schedule Tour" clicks as conversions. That is the number the committee will
actually want at the next meeting — not pageviews.

**Effort once we have it.** An hour.

---

## 5. Launch-day items

These are ours to do, listed so nothing is forgotten. They are held
deliberately until the domain is final.

- Remove the `noindex, nofollow` header. The preview is currently invisible
  to search engines on purpose. **This must come off at launch or the site
  will never rank.**
- Add canonical tags pointing at the live domain.
- Point the sitemap at the live domain and submit it to Google Search
  Console.
- Re-check the member login link against the live site.

---

## Closed

- **Dining "The Venues" photograph.** Reviewed the replacement and decided
  against it. Keeping the current image.
