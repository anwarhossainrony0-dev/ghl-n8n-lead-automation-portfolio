# GHL follow-up workflows (hot / warm / cold) — blueprint

n8n puts **one** tier tag on every scored contact: `lead-hot`, `lead-warm` or `lead-cold` (plus `n8n-scored`), and removes the other two. Build 3 workflows in GoHighLevel that start when one of those tags is added.

Build them in the sub-account: **Automation → Workflows → + Create Workflow → Start from Scratch**.

## Rules for all 3 workflows

1. **Trigger:** **Contact Tag** → filter **Tag Added** → **is** → `lead-hot` / `lead-warm` / `lead-cold` (one tag per workflow).
2. **"Remove from other tier workflows" rule:** the **first action** in each workflow is **Remove From Workflow** → pick the **other two** tier workflows. A lead that moves up (cold → hot on a second submission) leaves the slow sequence straight away, so they never get two sequences at once.
3. **Settings (gear icon):**
   - **Allow re-entry: ON** (a lead can come back to a tier later).
   - **Stop on response: ON** (when the lead replies by SMS/email, the sequence stops and you take over).
   - **Time window for SMS/calls:** Mon–Sat 8:00 AM – 8:00 PM, **contact's time zone**. Emails can go any time.
4. **Exit when booked/won:** add a **Goal Event** at the end → *Appointment status = booked* **or** *Opportunity status = won* → the contact jumps out of the sequence.
5. SMS steps: put an **If/Else** before them: *Phone is not empty*. Cold leads often have no phone.
6. Repeat submissions: if a hot lead sends the form again, `lead-hot` is already on the contact, so GHL doesn't fire *Tag Added* again. They don't get the sequence twice. You still get the n8n Telegram alert marked *Duplicate: yes*.
7. Change `{{location.name}}`, `{{user.name}}` and phone numbers in the copy to fit your business. Custom values like `{{contact.first_name}}` are filled in by GHL.

---

## 1) 🔥 Hot — "Lead Hot – Speed to Lead"

Goal: talk to them within **5 minutes**.

| When | Action | Details |
|---|---|---|
| 0 min | Remove From Workflow | `Lead Warm – Nurture`, `Lead Cold – Nurture` |
| 0 min | Internal Notification (SMS + email to you / the team) | Copy H-0 below |
| 0 min | Create Task | "Call {{contact.name}} NOW (hot roofing lead)", assigned to owner, due in 15 min |
| 0 min | Send SMS | H-1 |
| 0 min | Send Email | H-E1 |
| Wait 10 min | If/Else: replied **or** appointment booked? | yes → End · no → next |
| 10 min | Send SMS | H-2 |
| Wait 2 hours | Send SMS | H-3 |
| Day 1 (next day, 10:00 AM) | Send Email | H-E2 |
| Day 2 (10:00 AM) | Send SMS | H-4 |
| Day 4 (10:00 AM) | Send Email | H-E3 → then move opportunity to "Follow-up" stage (optional) → End |

**H-0 — internal notification**
```
🔥 HOT roofing lead: {{contact.name}} {{contact.phone}}
Address: {{contact.address1}}
Call within 5 minutes. Details are in the n8n Telegram alert.
```

**H-1 — SMS (0 min)**
```
Hi {{contact.first_name}}, this is {{user.first_name}} from {{location.name}}. Got your roof estimate request - we can come out fast. Is now a good time for a quick call? Reply STOP to opt out.
```

**H-2 — SMS (10 min)**
```
{{contact.first_name}}, just tried to reach you about your roof. If you have an active leak, put a bucket under it and move valuables away - we can tarp it today. What time works for a call?
```

**H-3 — SMS (2 hours)**
```
Hi {{contact.first_name}}, still want that free roof inspection? We have openings today and tomorrow. Reply with a time, or book here: {{calendar.link}}
```

**H-4 — SMS (day 2)**
```
{{contact.first_name}}, quick check-in from {{location.name}}. Storm or insurance claim? We'll document the damage with photos and help you with the claim at no cost. Want us to stop by?
```

**H-E1 — Email (0 min)**
Subject: `Your free roof estimate - next steps`
```
Hi {{contact.first_name}},

Thanks for reaching out to {{location.name}}. We got your request for {{contact.address1}}.

Here's what happens next:
1. We call you to understand the problem (5 minutes).
2. A roofing specialist inspects the roof - free, no obligation.
3. You get a clear written estimate, with photos.

If water is coming in right now, call us at {{location.phone}} - we offer same-day emergency tarping.

Talk soon,
{{user.name}}
{{location.name}} | {{location.phone}}
```

**H-E2 — Email (day 1)**
Subject: `Should we take a look at your roof today?`
```
Hi {{contact.first_name}},

I haven't been able to reach you yet. Small leaks and storm damage get worse (and more expensive) fast, so I wanted to make sure you're taken care of.

Pick a time that works for you: {{calendar.link}}
Or just reply to this email with a good time to call.

{{user.name}}
{{location.name}}
```

**H-E3 — Email (day 4)**
Subject: `Closing your estimate request`
```
Hi {{contact.first_name}},

I'll close your request for now so I stop filling your inbox. If you still need help with your roof - repair, replacement or an insurance claim - just reply "YES" and we'll get you on the schedule.

Thanks,
{{user.name}}
{{location.name}} | {{location.phone}}
```

---

## 2) 🌤 Warm — "Lead Warm – Nurture"

Goal: book an inspection within 1–2 weeks.

| When | Action | Details |
|---|---|---|
| 0 min | Remove From Workflow | `Lead Hot – Speed to Lead`, `Lead Cold – Nurture` |
| 0 min | Send Email | W-E1 |
| 5 min | If/Else phone not empty → Send SMS | W-1 |
| Day 1 (10:00 AM) | Create Task | "Call {{contact.name}} (warm roofing lead)" |
| Day 2 (10:00 AM) | Send SMS | W-2 |
| Day 4 (10:00 AM) | Send Email | W-E2 |
| Day 7 (10:00 AM) | Send SMS | W-3 |
| Day 10 (10:00 AM) | Send Email | W-E3 → End |

**W-1 — SMS (5 min)**
```
Hi {{contact.first_name}}, {{user.first_name}} from {{location.name}} here. Thanks for your estimate request! When would be a good time for a free roof inspection this week? Reply STOP to opt out.
```

**W-2 — SMS (day 2)**
```
Hi {{contact.first_name}}, do you have 10 minutes this week? We'll check your roof, take photos, and give you a written estimate - free. Book here: {{calendar.link}}
```

**W-3 — SMS (day 7)**
```
{{contact.first_name}}, still thinking about your roof project? Happy to answer any questions by text - price ranges, materials, timelines. Just reply here.
```

**W-E1 — Email (0 min)**
Subject: `Thanks for your roof estimate request`
```
Hi {{contact.first_name}},

Thanks for contacting {{location.name}}! We'd love to help with your roof.

Your free estimate includes:
- A full roof inspection with photos
- Honest advice: repair vs. replacement
- A written price with no pressure

Book a time that suits you: {{calendar.link}}

{{user.name}}
{{location.name}} | {{location.phone}}
```

**W-E2 — Email (day 4)**
Subject: `Repair or replace? A quick guide`
```
Hi {{contact.first_name}},

A question we hear a lot: "Do I need a new roof, or just a repair?"

A repair is usually enough when the damage is in one area and the roof is under ~15 years old. Replacement makes sense when shingles are curling or missing in many places, there are repeated leaks, or the roof is 20+ years old.

The easiest way to know for sure is a free inspection: {{calendar.link}}

{{user.name}}
{{location.name}}
```

**W-E3 — Email (day 10)**
Subject: `Still want that free roof estimate?`
```
Hi {{contact.first_name}},

Just checking in one last time. If now isn't the right time, no problem - reply "LATER" and we'll check back in a few months. If you're ready, book here: {{calendar.link}}

{{user.name}}
{{location.name}} | {{location.phone}}
```

---

## 3) ❄️ Cold — "Lead Cold – Nurture"

Goal: stay helpful and in their mind without pushing. Mostly email.

| When | Action | Details |
|---|---|---|
| 0 min | Remove From Workflow | `Lead Hot – Speed to Lead`, `Lead Warm – Nurture` |
| 0 min | Send Email | C-E1 |
| Day 3 (10:00 AM) | Send Email | C-E2 |
| Day 10 (10:00 AM) | Send Email | C-E3 |
| Day 21 (10:00 AM) | If/Else phone not empty → Send SMS | C-1 |
| Day 30 (10:00 AM) | Send Email | C-E4 → End |

**C-E1 — Email (0 min)**
Subject: `We got your message`
```
Hi {{contact.first_name}},

Thanks for reaching out to {{location.name}}. Whenever you're ready, we're happy to give you a free roof inspection and estimate - no pressure.

Have a question first? Just reply to this email.

{{user.name}}
{{location.name}} | {{location.phone}}
```

**C-E2 — Email (day 3)**
Subject: `What does a new roof cost? (honest answer)`
```
Hi {{contact.first_name}},

Roof prices depend on 3 things: the size of the roof, the material (asphalt shingles, metal, tile), and how many layers need to come off.

The only way to get a real number is to measure, so our estimates are always free. Want one? {{calendar.link}}

{{user.name}}
{{location.name}}
```

**C-E3 — Email (day 10)**
Subject: `5 signs your roof needs attention`
```
Hi {{contact.first_name}},

Quick checklist you can do from the ground:
1. Shingles that are curling, cracked or missing
2. Granules (like sand) in the gutters
3. Dark streaks or moss
4. Water stains on ceilings or in the attic
5. Daylight through the attic boards

See any of these? We'll check it for free: {{calendar.link}}

{{user.name}}
{{location.name}}
```

**C-1 — SMS (day 21)**
```
Hi {{contact.first_name}}, {{location.name}} here. Any questions about your roof we can help with? Free inspections this month. Reply STOP to opt out.
```

**C-E4 — Email (day 30)**
Subject: `After the next storm...`
```
Hi {{contact.first_name}},

Storm season is the busiest time for roofers. If you get hail or wind damage, call us at {{location.phone}} - we help with photos and paperwork for insurance claims at no extra cost.

Keep this email handy.

{{user.name}}
{{location.name}}
```

---

## Checklist

- [ ] 3 workflows created, each triggered by **Contact Tag → Tag Added** with its own tier tag
- [ ] First action in each = **Remove From Workflow** (the other two)
- [ ] Allow re-entry ON, Stop on response ON, SMS time window set
- [ ] Goal event: appointment booked / opportunity won
- [ ] `{{calendar.link}}` replaced with your booking calendar link (or custom value)
- [ ] All 3 **Published**
- [ ] Test: add the tag `lead-warm` by hand to a test contact → the warm workflow starts; then add `lead-hot` → the contact leaves warm and starts hot
