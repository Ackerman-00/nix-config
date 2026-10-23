# Booking App for Your Sister's Dog Grooming Salon — Plan and Tool Picks

## Your direct questions, answered first

**Should you use Lovable?** Yes — for the right phase. Lovable is a great fit for the *prototype and validation* stage: it produces a clickable web app fast, and at that stage the tool barely matters (Lovable, Replit, or plain Claude chat — whatever you already pay for). The ads are irrelevant to the decision either way. What Lovable should *not* automatically be is your long-term builder. That choice comes later and is made on three checks: pricing model, code ownership, and feel — not on ad spend.

**Do you actually need a mobile app?** For a salon booking flow: start on the web, and you may never need to leave it. The only strong pull toward native is push notifications for appointment reminders — but SMS/email reminders usually cover that for a business this size. Use the tiebreak rule below after the prototype.

**What tools I'd pick, and why:**

| Stage | Pick | Why |
|---|---|---|
| Prototype (days 1–2) | Lovable, Replit, or Claude — whatever you already pay for | Fastest path to a clickable web app; tool choice doesn't matter here |
| Validation (week 1) | No new tool — put the prototype in front of real people | Ideas die in validation, not in code |
| Long-term web builder | Claude Code / Cursor on a plain codebase you own, or a builder with free code export | You'll maintain this for years; per-credit billing compounds, and locked exports trap you |
| If it truly needs to be mobile | React Native + Expo as the pragmatic fallback; a native-generating builder only if it passes the three checks | One project covers iOS + Android; native (Swift + Kotlin) is the long-term ideal if you commit |
| Before any of the above | Off-the-shelf check: Fresha, Booksy, Square Appointments, MoeGo-style platforms | The cheapest build is the one you don't do — study their pricing, reviews, and complaints |

## 1. Define exactly what you're building

Two users share one product:

- **Her clients** — book an appointment from their phone in under a minute, get a reminder, show up.
- **Your sister** — see and manage her day: calendar, availability, requests, reminders, no-shows, maybe deposits.

You're on the "validated category" path: booking software is a solved market. That's good news — demand is proven, and competitors' pricing, reviews, and complaints are visible. Study them. Your edge is not a novel booking concept; it's your sister's actual workflow (deposit rules? no-shows? service durations by breed and coat? before/after photos for social?).

Talk to her before anything else. And answer honestly: if an off-the-shelf platform covers 90% of what she needs, that's your answer — don't build. A custom app wins when her workflow is specific enough that generic tools annoy her daily.

## 2. Prototype and validate on web first (1–2 weeks)

- Two days on the prototype, then a full week with real users.
- Build a mobile **web** version — Lovable, Replit, or Claude chat. Clickable, ugly-fine, fast.
- Questions to answer: Is booking through this actually pleasant? Does the flow make sense? Which features does your sister need on day one vs. never?
- Put it in front of your sister and 5–10 of her real clients. A short questionnaire works.
- Expect to pivot often or drop it entirely. That is the point — learn it before spending real mobile effort.

## 3. Decide web or mobile — the tiebreak rule

The web version decides:

- Web good enough = **stay web**. Do not build native because it feels like "real".
- Web blocked by real mobile needs (installed app, notifications, widgets, camera, store presence) = go native.

For a booking app, the honest assessment:

| The habit | Does it force native? |
|---|---|
| Clients book from a phone browser | No — web handles it |
| Appointment reminders | Usually no — SMS/email reminders are the practical choice for salons |
| Store presence / brand credibility | Marginal — a link in the Instagram bio and Google profile does most of the work |
| The salon owner manages her schedule | No — phone browser is fine |

Verdict for this project: **web first, likely stay web** (you can make it installable as a PWA). Build native only if, after validation, reminders/notifications turn out to be the feature people actually demand — and expect a full rebuild from web to native if so. The rebuild is far easier than the first build: you'll already know exactly what to build.

If you do go mobile:

| Option | Verdict |
|---|---|
| Wrapper (Capacitor, Despia) | Fast, but temporary. A shortcut, not a destination. |
| React Native + Expo | Solid cross-platform default; most AI builders support it. |
| Native (Swift + Kotlin) | Best long-term answer where the market is moving; AI has cut the cost enough that a non-specialist can do it. More complex, worth it. |

## 4. Map the app flow by flow

Before any code, sketch it on paper. Split everything into flows:

- Client booking: choose service → pick date and time → enter details (and dog details) → confirm → reminder → maybe deposit.
- Client accounts: their pets, history, rebooking.
- Owner schedule: calendar, availability, day view, manage and move bookings.
- Notifications: reminders, confirmations, cancellations.
- Monetization flow: deposits and no-show/cancellation policy (salons live and die by no-shows).
- Optional later: before/after photos, review requests.

Use the web prototype screenshots as reference, then ask what differs on a phone. Browse [mobbin.com](https://mobbin.com) to see how real booking apps structure these flows.

## 5. Write the PRD

A product requirements document, flow by flow — this is the context you hand to the AI builder. Co-write it with Claude. Without a PRD the agent guesses and invents the product; with one it follows your plan.

## 6. Choose a builder — three checks

This is where "should I use Lovable?" gets its real answer, for the long-term tool:

1. **Pricing model:** prefer tools that let you plug in your own AI agent or subscription (Claude, Cursor) over per-credit billing. You will maintain this app for years — per-credit costs compound. Cheapest option that works usually wins; this is a long play.
2. **Code ownership:** you must always be able to take your code and leave, free. Some tools gate exports behind expensive plans. Check the current terms before you invest anything.
3. **Feel:** try it for real work. Comfort compounds across months of iteration.

Then apply the checks. If web-only: prototype in Lovable, rebuild into a codebase you own (Claude Code or Cursor on your own subscription is the boring, maintainable answer for a long-lived business tool). If both platforms are genuinely needed: prefer a tool that produces both platforms, ideally native Swift and Kotlin from one project — and if nothing fits that bar on the three checks, React Native + Expo is the pragmatic fallback.

## 7. Build flow by flow

One flow = one spec + screenshots, one prompt cycle at a time. **Never ask for the whole app in one prompt.**

- Full-time effort: a week or two for an app like this. Side-project pace: one to two months is fine.
- Budget ~30% of total time for debugging and verification.

## 8. Test and release fast

- Your testers: your sister and 5–7 real clients. Collect feedback from each one individually.
- Apple Developer Program: $99/year; ship builds via TestFlight.
- Google Play: $25 one-time; new personal accounts need a closed test (12 testers for 14 days) before public release.
- No testers? Release free and learn from real store users.
- Pricing optional at the start — ship free, monetize later (the salon's monetization is deposits and fewer no-shows, not app fees).

The faster you release, the faster you learn. Ship feature by feature.

## Mistakes to avoid on this project

| Mistake | Correction |
|---|---|
| Building native before validating | Web prototype + real users first (steps 2–3) |
| Skipping the off-the-shelf comparison | Check Fresha/Booksy/Square-class tools first; maybe you don't build at all |
| Asking for the whole app in one prompt | Flow by flow, spec per flow |
| Skipped PRD | The AI invents the product instead of building hers |
| Per-credit billing on a long-lived app | Own-agent tooling on your own subscription |
| Plan that can't export code free | Verify ownership before starting |
| Waiting for polish to release | TestFlight at 5–7 users, ship the version |

## The short version

Lovable: yes, for the two-day prototype and validation week. Long-term builder: decide with the three checks — my pick for a web tool is owning your own code with Claude/Cursor on a subscription you already pay for. Mobile: probably unnecessary; stay web unless reminders/notifications prove otherwise, and if you go mobile use React Native + Expo or a native-generating tool that passes the checks. And before any of it: check whether an off-the-shelf salon platform already wins.
