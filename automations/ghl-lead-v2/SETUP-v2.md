# GHL → n8n Lead Automation **v2** — Setup Guide

**What v2 does:** when someone sends the **Roofing Free Estimate Form** in GoHighLevel, GHL sends the contact to n8n. n8n:

1. answers GHL with `200 OK` straight away (GHL never waits or times out),
2. cleans the data (email, phone, names, the 4 form fields, ad/UTM info),
3. throws away junk (no email and no phone, throw-away email, spam) into a `Rejected` tab,
4. checks if this contact already sent the form before (repeat = duplicate),
5. gives the lead a **score from 0 to 100** and a **tier**: 🔥 hot, 🌤 warm or ❄️ cold,
6. puts tags `lead-hot` / `lead-warm` / `lead-cold` + `n8n-scored` on the contact in GHL, and for hot and warm leads creates an **opportunity** in your *Marketing Pipeline*,
7. writes / updates one row per contact in the `Leads_v2` tab,
8. sends a **Telegram alert only for hot leads**. Warm and cold leads come in a **daily digest at 9:00 (Dhaka time)**.

If a step fails, a separate **Error Alert** workflow sends you a Telegram message.

v1 (`automations/ghl-new-lead/`) is not changed. You can switch back any time (see [Rollback](#rollback)).

```
GHL workflow (Form Submitted: Roofing Free Estimate Form)
 └─ Webhook action (POST) ──► n8n  GHL Webhook v2  (answers 200 at once)
     └─ Validate + Normalize
         └─ Is Valid?
             ├─ no  → Append Rejected (tab "Rejected") → stop
             └─ yes → Lookup Lead (tab "Leads_v2", by contact_id)
                       └─ Score Lead (score, tier, duplicate?)
                           └─ Has GHL Contact ID?
                               ├─ yes → GHL Remove Tier Tags → GHL Add Tier Tags → Hot or Warm?
                               │          ├─ yes → GHL Get Pipelines → Pick Pipeline Stage → Stage Found? → GHL Upsert Opportunity
                               │          └─ no (cold) ─────────────────────────────────────────────┐
                               └─ no ───────────────────────────────────────────────────────────────┤
                           Collect GHL Result  ◄───────────────────────────────────────────────────┘
                               └─ Upsert Leads_v2 (one row per contact)
                                   └─ Is Hot? → yes → Telegram Hot Alert
```

GHL steps **never stop the flow**: each one retries 3 times, and if it still fails the lead is still saved and the hot alert still goes out. The `ghl_sync` column then says `failed: <reason>`.

---

## Files in this folder

| File | What it is |
|---|---|
| `workflow-main.json` | **GHL Lead Automation v2** — the main workflow (webhook path `ghl-lead-v2`) |
| `workflow-daily-digest.json` | **GHL v2 - Daily Lead Digest** — Telegram summary every day at 09:00 Asia/Dhaka |
| `workflow-error-alert.json` | **GHL v2 - Error Alert** — Telegram message when a workflow fails |
| `workflow-setup-sheets.json` | **GHL v2 - Setup Sheets** — run once, creates the `Leads_v2` and `Rejected` tabs with headers |
| `SCORING.md` | The scoring rules as a table, and how to change them |
| `GHL-FOLLOWUP.md` | Blueprint + ready-to-paste email/SMS copy for 3 GHL follow-up workflows (hot / warm / cold) |
| `test-payloads/*.json` | Fake form submissions: `hot`, `warm`, `cold`, `invalid`, `duplicate` (same contact as `hot`) |
| `test-webhook.sh` | Sends a test payload to n8n with `curl` |
| `tests/run-tests.js` | Offline tests for the scoring code — run `node tests/run-tests.js` |

No passwords, tokens or IDs are in these files. They use placeholders that you fill in.

## Placeholders

| Placeholder | Replace with | Where |
|---|---|---|
| `__SHEET_ID__` | Your Google Sheet ID (the long part between `/d/` and `/edit` in the sheet URL) | All Google Sheets nodes (main, digest, setup) |
| `__GOOGLE_CRED_ID__` / `__GOOGLE_CRED_NAME__` | Your **Google Service Account** credential (type *Google API*) | All Google Sheets nodes |
| `__TELEGRAM_CRED_ID__` / `__TELEGRAM_CRED_NAME__` | Your Telegram bot credential (type *Telegram API*) — the v1 bot is fine | All Telegram nodes |
| `__TELEGRAM_CHAT_ID__` | Your Telegram chat ID (same as v1) | All Telegram nodes |
| `__GHL_CRED_ID__` / `__GHL_CRED_NAME__` | A **Header Auth** credential with your GHL Private Integration token (Step 3) | The 4 `GHL …` HTTP Request nodes in the main workflow |

**Two ways to fill them:**

- **In n8n (simple):** import the file, open each red node, pick the credential from the list, and paste the Sheet ID / chat ID.
- **Before import (faster):** open the JSON in a text editor and use *Find & Replace* for `__SHEET_ID__` and `__TELEGRAM_CHAT_ID__`. If you also replace `__GOOGLE_CRED_ID__` (etc.) with the real credential ID (open the credential in n8n — the ID is the last part of the URL) and `__GOOGLE_CRED_NAME__` with its exact name, n8n links the credentials by itself.

---

## Step 1 — Google Sheet + service account

The Sheets nodes use **Service Account** authentication.

1. Use your existing leads spreadsheet, or create a new one (e.g. `Datapulse Leads`). Copy its **Sheet ID** from the address bar:
   `https://docs.google.com/spreadsheets/d/`**`1AbCdEf...xyz`**`/edit`
2. If you don't have a service account credential in n8n yet:
   1. Go to <https://console.cloud.google.com> → pick/create a project → **APIs & Services → Library** → enable **Google Sheets API** (and **Google Drive API**).
   2. **APIs & Services → Credentials → Create credentials → Service account** → give it a name → **Done**.
   3. Open the service account → **Keys → Add key → Create new key → JSON**. A file downloads.
   4. In n8n: **Credentials → Add credential → Google API** (Service Account). Paste the `client_email` into *Service Account Email* and the `private_key` (whole thing, with `-----BEGIN…`) into *Private Key*. Save.
3. **Share the spreadsheet** with the service account email (looks like `name@project.iam.gserviceaccount.com`) as **Editor**. Without this every Sheets node fails with 403.

## Step 2 — Telegram

Use the same bot and chat ID as v1 (see `../ghl-new-lead/SETUP.md`, Step 2). In n8n you should already have the *Telegram API* credential.

## Step 3 — GHL Private Integration token

The main workflow talks to GHL with a **Private Integration** token of the **sub-account** (location) where the form lives.

1. In GoHighLevel, switch to the sub-account (e.g. **Datapulse**).
2. Go to **Settings → Private Integrations**. (If you don't see it: Agency view → Settings → Labs, turn on Private Integrations.)
3. Click **Create new Integration**. Name: `n8n lead scoring v2`. Description: optional.
4. Select these **scopes**:
   - `contacts.write` (add / remove tags)
   - `opportunities.readonly` (read pipelines and stages)
   - `opportunities.write` (create / update the opportunity)
5. Click **Create**, then **copy the token** (starts with `pit-…`). GHL only shows it once — keep it somewhere safe.
6. In n8n: **Credentials → Add credential → Header Auth**:
   - **Name:** `Authorization`
   - **Value:** `Bearer pit-xxxxxxxx…` (the word `Bearer`, one space, then the token)
   - Credential name: e.g. `GHL Private Integration (Datapulse)`. Save.

> **No token yet?** Create the Header Auth credential anyway with a dummy value like `Bearer not-set-yet`. n8n needs a credential to activate the workflow. The GHL steps will fail softly (`ghl_sync = failed: …`) and everything else works. Put the real token in later.

**Pipeline names:** the workflow looks for the pipeline **`Marketing Pipeline`** with stages **`Hot Lead`** (for hot) and **`New Lead`** (for warm). Upper/lower case doesn't matter. If your names are different, change them in the `CONFIG` object at the top of the **Score Lead** node (`pipelineName`, `stageNames`).

## Step 4 — Import the workflows (in this order)

In n8n: **Create Workflow → ⋯ (top right) → Import from File…**, then **Save**. Do it once per file:

| # | File | Then |
|---|---|---|
| 1 | `workflow-error-alert.json` | Set Telegram credential + chat ID. Save. **Don't activate** (error workflows run by themselves). |
| 2 | `workflow-setup-sheets.json` | Set Google credential on the 3 Sheets nodes + Sheet ID. Save. Click **Execute workflow** once (Step 5). |
| 3 | `workflow-main.json` | Set credentials on all Sheets, GHL and Telegram nodes; Sheet ID; chat ID. Then **⋯ → Settings → Error workflow → GHL v2 - Error Alert**. Save. |
| 4 | `workflow-daily-digest.json` | Set Google + Telegram credentials, Sheet ID, chat ID. **⋯ → Settings → Error workflow → GHL v2 - Error Alert**. Save. |

Error workflow first, so you can pick it in the Settings of 3 and 4.

## Step 5 — Create the sheet tabs (run once)

1. Open **GHL v2 - Setup Sheets** → **Execute workflow**.
2. Check the spreadsheet: tabs **`Leads_v2`** (24 headers, A→X) and **`Rejected`** (8 headers, A→H) are there. Tabs that already existed are not touched (at most a blank row is added at the end).
3. Select column **H** (`phone`) in `Leads_v2` and column **F** (`phone`) in `Rejected` → **Format → Number → Plain text**. (n8n already writes RAW text, this is extra safety so `+1512…` never turns into a number.)
4. Don't rename or reorder the headers. If you do, open the Sheets nodes in the main workflow and click refresh on *Columns*.

`Leads_v2` columns:
`contact_id, first_seen, last_seen, submission_count, first_name, last_name, email, phone, property_address, help_topic, message, website, source, session_source, utm_source, utm_medium, utm_campaign, country, score, tier, score_reasons, ghl_sync, ghl_opportunity_id, location_name`

`Rejected` columns:
`received_at, reason, contact_id, name, email, phone, source, raw_json` (`raw_json` = the original webhook body, cut to 2000 characters)

## Step 6 — Test n8n on its own

1. Open **GHL Lead Automation v2** → click **Execute workflow** (n8n listens for ~2 minutes).
2. On your computer, in this folder:
   ```bash
   ./test-webhook.sh hot --test
   ```
   (Windows: Git Bash or WSL.) You should see `HTTP 200` and `{"message":"Workflow was started"}`.
3. Click **Execute workflow** again before each test-URL call, and try the others:

| Payload | Expected result |
|---|---|
| `hot` | Row in `Leads_v2`, score **90**, tier `hot`, tags `lead-hot` + `n8n-scored` in GHL*, opportunity in *Hot Lead*, **Telegram alert** |
| `duplicate` (send after `hot`) | Same row updated: `submission_count` 2, `first_seen` kept, score **100**, Telegram alert says *Duplicate: yes* |
| `warm` | Row, score **40**, tier `warm`, opportunity in *New Lead*, no Telegram |
| `cold` | Row, score **25**, tier `cold`, tags only, no Telegram |
| `invalid` | Row in `Rejected` with reason `disposable email domain (mailinator.com)`, nothing else |

\* The test contacts don't exist in your GHL, so with a real token the GHL steps show `ghl_sync = failed: … not found`. That is expected. To test GHL for real, submit the real form (Step 8).

4. Delete the test rows when done.

Offline check of the scoring code (no n8n needed): `node tests/run-tests.js` → `25 passed, 0 failed`.

## Step 7 — Activate

1. **GHL Lead Automation v2** → toggle **Active** (on newer n8n: **Publish**). Only active workflows answer on `/webhook/…`.
2. **GHL v2 - Daily Lead Digest** → **Active / Publish**. The time zone (Asia/Dhaka) is already set in its Settings.
3. Production webhook URL:
   `https://blueviolet-parrot-909837.hostingersite.com/webhook/ghl-lead-v2`
   Test it: `./test-webhook.sh cold` (without `--test`).

## Step 8 — Switch GHL from v1 to v2

1. GoHighLevel → sub-account → **Automation → Workflows** → open your form workflow (e.g. `New Lead -> n8n`).
2. Click the **Webhook** action and change the **URL**
   from `…/webhook/ghl-new-lead`
   to `https://blueviolet-parrot-909837.hostingersite.com/webhook/ghl-lead-v2`
   Method stays **POST**. **Save Action**, then **Save** the workflow (it must be **Published**).
3. Make sure the trigger is **Form Submitted → Roofing Free Estimate Form**, so the 4 form fields (`How can we help?`, `Your website`, `Message`, `Property Address`) are in the webhook body.
4. Submit the real form once with your own details and check: green run in n8n **Executions**, row in `Leads_v2` with `ghl_sync = ok`, tags on the contact in GHL, opportunity in *Marketing Pipeline* (if hot/warm), Telegram alert (if hot).
5. v1 now gets nothing. You can leave it active (harmless) or deactivate it.

> Want to run both for a few days? Add a **second** Webhook action in the same GHL workflow with the v2 URL and keep the v1 one. v1 writes to `Leads`, v2 to `Leads_v2`, so they don't clash. Remove the v1 action when you are happy.

Next: build the follow-up workflows in GHL — see `GHL-FOLLOWUP.md`.

## Rollback

1. In the GHL Webhook action, change the URL back to `…/webhook/ghl-new-lead` → Save → Save workflow.
2. Make sure the v1 workflow (**GHL New Lead -> Sheets + Telegram (Datapulse)**) is **Active** in n8n.
3. Deactivate **GHL Lead Automation v2** and **GHL v2 - Daily Lead Digest**.
4. Optional: in GHL, pause the 3 tier follow-up workflows, and bulk-remove the tags `lead-hot`, `lead-warm`, `lead-cold`, `n8n-scored` (Contacts → filter by tag → select all → Remove tag).
5. `Leads_v2` and `Rejected` stay in the sheet; they don't affect v1.

## Optional hardening — secret header on the webhook

The webhook URL is public. To make n8n refuse requests that don't carry a secret:

1. Make a long random string, e.g. run `openssl rand -hex 24`.
2. n8n: **Credentials → Add credential → Header Auth** → Name `X-Webhook-Secret`, Value = your random string. Credential name e.g. `GHL webhook secret`.
3. Main workflow → **GHL Webhook v2** → **Authentication: Header Auth** → pick that credential → Save. (Requests without the header now get `403`.)
4. GHL → your form workflow → **Webhook** action → **Headers** → add key `X-Webhook-Secret`, value = the same string → Save. If your Webhook action has no *Headers* section, use the **Custom Webhook** action (it has headers), or skip this hardening.
5. Test: `WEBHOOK_SECRET=<the string> ./test-webhook.sh cold` → 200; without it → 403.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `404` on `/webhook/ghl-lead-v2` | Main workflow not active | Activate / Publish it (Step 7). |
| `404` on `/webhook-test/…` | n8n isn't listening | Click **Execute workflow** first, then send within ~2 min. |
| `403` from the webhook | Hardening is on, header missing / wrong | Check the header name and value in GHL and in the n8n credential. |
| GHL shows the webhook OK but no row | n8n answers 200 before processing, so GHL can't see failures | Look in n8n **Executions** (and your Telegram error alert). |
| Can't activate: "issues" / credential missing | A node has no credential | Pick credentials on every Sheets, GHL and Telegram node. For GHL use a dummy token if needed (Step 3). |
| Sheets: "Sheet with name Leads_v2 not found" | Setup workflow not run / tab renamed | Run **GHL v2 - Setup Sheets** (Step 5). |
| Sheets: 403 / "The caller does not have permission" | Sheet not shared with the service account | Share it with the `…iam.gserviceaccount.com` email as Editor. |
| Sheets: "Column names were updated after the node's setup" | Headers renamed / missing | Restore the exact headers (Step 5) or refresh *Columns* in the node. |
| Every lead `duplicate` | Re-sending the same test payload | Expected: same `contact_id` = same person. Delete the test row to start fresh. |
| `ghl_sync = failed: … 401` / `Invalid JWT` | Token wrong or missing `Bearer ` | Header Auth value must be `Bearer pit-…`. |
| `ghl_sync = failed: … 403` / scope | Missing scope | Edit the Private Integration and add `contacts.write`, `opportunities.readonly`, `opportunities.write`. |
| `ghl_sync = failed: pipeline "Marketing Pipeline" not found` | Different pipeline name | Fix the name in GHL or in `CONFIG` (Score Lead). Same for `stage "…" not found`. |
| `ghl_sync = failed: … contact not found` | Test payload contact doesn't exist in GHL, or token is from another sub-account | Normal for test payloads. For real leads, make the token in the same sub-account as the form. |
| `ghl_sync = skipped` | Webhook had no `contact_id` (row key is `email:…` or `phone:…`) | Make sure the GHL trigger is Form Submitted / Contact based so `contact_id` is sent. |
| No Telegram for a lead | Only **hot** leads alert instantly | Warm/cold appear in the 09:00 digest. Check the `tier` column. |
| Telegram "can't parse entities" | Unusual characters | Text is HTML-escaped; if it still happens, look at the failed Telegram node output. |
| Daily digest at the wrong time | Time zone | Digest workflow → Settings → Timezone = `Asia/Dhaka`. |
| Phone shows as `1.51E+10` | Column formatted as number | Format the phone column as **Plain text**. |
| Two rows for the same person | Two submissions in the same second (race), or contact_id was missing once | Rare; delete the extra row. |
