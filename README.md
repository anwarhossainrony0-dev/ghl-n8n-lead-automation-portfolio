# Lead scoring rules (v2)

All numbers, keywords, tier limits, tag names and pipeline names live in **one `CONFIG` object at the top of the `Score Lead` Code node** in `workflow-main.json`. Change them there; nothing else needs editing. After a change, run `node tests/run-tests.js` — some tests check exact scores and will tell you what moved.

## Points

| Signal | Points | How it is detected |
|---|---:|---|
| Valid phone | **+20** | Phone has 8–15 digits after cleanup (stored as `+digits`; a 10-digit number without `+` gets `+1`). Not all one digit, not `1234567890`. |
| Email | **+10** | Email looks valid (`name@domain.tld`, lowercased, spaces removed). |
| Business email | **+5** | Email domain is **not** a free provider (gmail, yahoo, hotmail, outlook, icloud, aol, proton, comcast, …; list in `CONFIG.freeEmailDomains`). |
| Property Address filled | **+15** | Form field `Property Address` (falls back to the contact's `full_address`). |
| Help topic / message | **+10** | `How can we help?` **or** `Message` is filled. |
| Urgency keyword | **+20** | Any of `leak, urgent, emergency, storm, damage, asap, insurance, today` at the start of a word in *How can we help?* or *Message* (so `leaking` counts). Counted once. |
| Paid traffic | **+10** | `gclid` or `fbclid` present (attribution field or landing-page URL), or `utmMedium` contains `cpc` / `ppc` / `paid` / `cpm`, or session source contains `Paid`. |
| Organic / referral | **+5** | Only if **not** paid: `utmMedium` or session source contains `organic` / `referral` / `social` / `seo`, or a referrer is set. |
| Repeat submission | **+15** | Same `contact_id` already in `Leads_v2`. |
| Test / spam pattern | **−30** | Name contains a word like `test, testing, asdf, qwerty, fake, dummy, spam, sample, n/a, none`, or the email starts with `test… / fake… / noreply…` or is `@test.* / @fake.* / @spam.*`. |

The total is clamped to **0–100**. Maximum possible before clamping is 105.

`score_reasons` lists every rule that fired, e.g.
`+20 valid phone, +10 email, +5 business email, +15 property address, +10 help topic / message, +20 urgency (leak, storm, today), +10 paid traffic`

## Tiers and what happens

| Tier | Score | GHL tags | GHL opportunity (Marketing Pipeline) | Telegram |
|---|---|---|---|---|
| 🔥 **hot** | **60–100** | add `lead-hot`, `n8n-scored`; remove `lead-warm`, `lead-cold` | upsert in stage **Hot Lead** | **instant alert** + daily digest count |
| 🌤 **warm** | **35–59** | add `lead-warm`, `n8n-scored`; remove `lead-hot`, `lead-cold` | upsert in stage **New Lead** | daily digest (listed) |
| ❄️ **cold** | **0–34** | add `lead-cold`, `n8n-scored`; remove `lead-hot`, `lead-warm` | none | daily digest (listed) |

Opportunity name: `<full name> - Roofing estimate (score N)`, status `open`. Upsert means a repeat submission updates the same opportunity instead of making a new one.

## Rejected before scoring (tab `Rejected`)

| Reason | Rule |
|---|---|
| `no email or phone` / `no usable email or phone` | Neither a valid email nor a valid phone. |
| `disposable email domain (…)` | Email domain is a throw-away service (mailinator, yopmail, 10minutemail, guerrillamail, …). List at the top of **Validate + Normalize**. |
| `junk: link in name` | Name contains `http`, `www.`, `.com` etc. |
| `junk: keyboard mash name` | Name like `asdfgh` or 6+ of the same letter. |
| `junk: spam phrase "…"` | Name / message contains `seo service, backlink, crypto, bitcoin, casino, …`. |
| `junk: many links in message` | 3 or more links in the message. |

Test-looking leads that **do** have a real phone or email are not rejected — they are kept and get −30 instead, so you can still see them.

## Examples (the test payloads)

| Payload | Signals | Score | Tier |
|---|---|---:|---|
| `hot.json` | phone 20 + email 10 + business 5 + address 15 + help 10 + urgency 20 + paid (gclid/cpc) 10 | **90** | hot |
| `duplicate.json` (after hot) | same as hot + repeat 15 = 105 → clamped | **100** | hot |
| `warm.json` | phone 20 + gmail 10 + help 10 (direct traffic, no address) | **40** | warm |
| `cold.json` | gmail 10 + message 10 + organic 5 (no phone) | **25** | cold |
| `invalid.json` | mailinator email, phone `123` | — | rejected |

## Changing things

- **Weights:** `CONFIG.points` (e.g. set `businessEmail: 0` to ignore it).
- **Tier limits:** `CONFIG.tiers` → `{ hot: 60, warm: 35 }`.
- **Keywords:** `CONFIG.urgencyKeywords` (lowercase).
- **Tag names:** `CONFIG.tierTags`, `CONFIG.scoredTag` — if you rename them, rename the GHL follow-up workflow triggers too.
- **Pipeline / stages:** `CONFIG.pipelineName`, `CONFIG.stageNames` (case-insensitive match). Remove `warm` from `stageNames` to stop creating opportunities for warm leads.
- **Disposable domains / spam phrases / default country code:** top of **Validate + Normalize**.
