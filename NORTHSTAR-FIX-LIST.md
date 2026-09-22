# Pine Lake Country Club - links still on the old hostname

Prepared 22 September 2026 for Northstar (ticket #996907). Every item below
was found by crawling all 43 pages of the member portal while logged in, and
every corrected address was verified to load (HTTP 200) on
`members.pinelakecc.com` the same afternoon.

**The rule for every item:** replace `https://pinelakecc.com/` with
`https://members.pinelakecc.com/`. Nothing after the hostname changes.

## A. ClubNow app - every menu item that opens a portal page

Any app item that opens a portal page by address must use
`https://members.pinelakecc.com/...`. Native modules (tee times, dining
reservations, statements, member roster) already work and need no change.

Members have confirmed these fail in the app; since 22 Sept they land on the
portal login page, which shows the app is still requesting the old hostname.
They are examples, not the full set - every page-based item matters equally.

| Example item | Must open |
|---|---|
| Current Menus | `https://members.pinelakecc.com/group/pages/current-menus` |
| Golf & Pro Shop | `https://members.pinelakecc.com/group/pages/golf-pro-shop1` |
| Swim Team Information | `https://members.pinelakecc.com/group/pages/swim-team-information` |
| Tennis Reservations | `https://members.pinelakecc.com/group/pages/tennis-reservations` |

For reference, these are all 43 portal pages that exist today. Any app item
that opens one of them must use the `members.` address:

    /group/pages/home                      /group/pages/club-calendar
    /group/pages/club-calendar1            /group/pages/clubcalendar
    /group/pages/clubcalendar-1            /group/pages/contact-us1
    /group/pages/current-menus             /group/pages/dining
    /group/pages/dining1                   /group/pages/dining-reservation1
    /group/pages/fitness1                  /group/pages/golf-instruction
    /group/pages/golf-outing               /group/pages/golf-outings
    /group/pages/golf-pro-shop             /group/pages/golf-pro-shop1
    /group/pages/golf-simulator            /group/pages/marina1
    /group/pages/member-roster             /group/pages/members-roster
    /group/pages/membership1               /group/pages/membership-information
    /group/pages/my-reservations           /group/pages/myprofile
    /group/pages/photo-gallery             /group/pages/photo-gallery1
    /group/pages/plcc-employee-scholarship-foundation1
    /group/pages/prospective-member-information
    /group/pages/recent-charges            /group/pages/request-for-boat-well-form
    /group/pages/request-information       /group/pages/rooms-capacity
    /group/pages/social-media              /group/pages/statementsummary
    /group/pages/swim                      /group/pages/swim1
    /group/pages/swim-team-information     /group/pages/tee-time-reservation
    /group/pages/tennis                    /group/pages/tennis-reservations
    /group/pages/viewprofile               /group/pages/weddings-parties
    /group/pages/makepayment

If the app stores a single base or portal URL for Pine Lake, it must be
`https://members.pinelakecc.com`. Members must arrive logged in, as they did
before the move.

## B. Portal navigation menu - 5 links (appear on every page)

| Menu label | Page id | Currently (old) | Must be |
|---|---|---|---|
| Bylaws | 120 | `https://pinelakecc.com/documents/20124/0/Bylaws+-+Updated+12102025+Revised+Appendix+May+2026.pdf/f22c2b07-c9c2-2dab-d75e-9280ef8a16be` | `https://members.pinelakecc.com/documents/20124/0/Bylaws+-+Updated+12102025+Revised+Appendix+May+2026.pdf/f22c2b07-c9c2-2dab-d75e-9280ef8a16be` |
| Golf House Rules | 136 | `https://pinelakecc.com/group/pages/house-rules-regulations` | `https://members.pinelakecc.com/group/pages/house-rules-regulations` |
| 2025 Penguins Swim Schedule | 174 | `https://pinelakecc.com/documents/20124/0/2025+Swim+Schedule.pdf/57532a5d-67d1-391c-b6c9-d8caab67d5f9` | `https://members.pinelakecc.com/documents/20124/0/2025+Swim+Schedule.pdf/57532a5d-67d1-391c-b6c9-d8caab67d5f9` |
| Recipients (Scholarship Foundation) | 184 | `https://pinelakecc.com/documents/20124/2860292/2024+Recipients%281%29.pdf/c9136b31-fa01-fa2a-10c8-577aeb2fa84c` | `https://members.pinelakecc.com/documents/20124/2860292/2024+Recipients%281%29.pdf/c9136b31-fa01-fa2a-10c8-577aeb2fa84c` |
| Donors (Scholarship Foundation) | 185 | `https://pinelakecc.com/documents/20124/2860292/2024+Donors.pdf/ee970917-acf1-5a33-434d-1ec64adbed93` | `https://members.pinelakecc.com/documents/20124/2860292/2024+Donors.pdf/ee970917-acf1-5a33-434d-1ec64adbed93` |

## C. Page content - 8 references inside web content

| Page | What | Currently (old) | Must be |
|---|---|---|---|
| Golf & Pro Shop (`/group/pages/golf-pro-shop1`) | Link "2025 Men's Priority Points for Men's Invitational" | `https://pinelakecc.com/documents/20124/7128168/Mens+Event+Participation+Points+4.15.25+-+Alpha.pdf/6cbe3ece-632d-bce2-224b-78d3868d314e` | `https://members.pinelakecc.com/documents/20124/7128168/Mens+Event+Participation+Points+4.15.25+-+Alpha.pdf/6cbe3ece-632d-bce2-224b-78d3868d314e` |
| Contact Us (`/group/pages/contact-us1`) | Staff photo | `https://pinelakecc.com/documents/20124/0/Scott+K.jpg/c5028ad6-5e8c-ab83-2c57-511bfd069cb9` | `https://members.pinelakecc.com/documents/20124/0/Scott+K.jpg/c5028ad6-5e8c-ab83-2c57-511bfd069cb9` |
| Contact Us | Staff photo | `https://pinelakecc.com/documents/20124/0/Terry+P.jpg/245bb674-3d43-4c6c-ab83-2663fcf7e195` | `https://members.pinelakecc.com/documents/20124/0/Terry+P.jpg/245bb674-3d43-4c6c-ab83-2663fcf7e195` |
| Contact Us | Staff photo | `https://pinelakecc.com/documents/20124/0/Patrick+S.jpg/0d7939ba-a832-a373-a58a-7ede4abfc0e4` | `https://members.pinelakecc.com/documents/20124/0/Patrick+S.jpg/0d7939ba-a832-a373-a58a-7ede4abfc0e4` |
| Contact Us | Staff photo | `https://pinelakecc.com/documents/20124/0/Peyton+W+new.jpg/a0202161-c4a0-2429-7598-e7405bbdfefb` | `https://members.pinelakecc.com/documents/20124/0/Peyton+W+new.jpg/a0202161-c4a0-2429-7598-e7405bbdfefb` |
| Contact Us | Staff photo | `https://pinelakecc.com/documents/20124/0/Laura+B.jpg/26d7f92a-6b50-acd7-5ada-119287d81661` | `https://members.pinelakecc.com/documents/20124/0/Laura+B.jpg/26d7f92a-6b50-acd7-5ada-119287d81661` |
| Contact Us | Staff photo | `https://pinelakecc.com/documents/20124/0/peter+N.jpg/ea1c97ce-62c3-c031-1ed7-3734866eccc8` | `https://members.pinelakecc.com/documents/20124/0/peter+N.jpg/ea1c97ce-62c3-c031-1ed7-3734866eccc8` |
| Contact Us | Staff photo | `https://pinelakecc.com/documents/20124/0/Tiffany+V.jpg/bbda9810-82e8-f6f9-71f7-198a8eacd392` | `https://members.pinelakecc.com/documents/20124/0/Tiffany+V.jpg/bbda9810-82e8-f6f9-71f7-198a8eacd392` |

Sections B and C currently work in a browser only because pinelakecc.com
redirects them to the portal; the redirect cannot carry a login, which is why
Section A fails in the app.

## D. Not visible to us - please search on your side

Any other stored link on `pinelakecc.com` in the Pine Lake setup: push
notification links, reservation and confirmation email templates, and the
`clubnow.pinelakecc.com` hostname, which still returns a 403 from your edge
and whose purpose we have not been told.
