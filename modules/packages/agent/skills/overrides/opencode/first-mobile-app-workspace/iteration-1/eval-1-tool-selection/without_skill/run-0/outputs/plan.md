# Booking app for a dog grooming salon — should you use Lovable, and what would I build it with?

*Prepared Oct 17, 2026. Prices, limits, and platform rules below were checked against current vendor documentation and 2026 industry roundups (sources at the end). These things change — re-verify before you pay.*

## TL;DR

- **The first decision is buy vs. build, not "Lovable or not."** For a single grooming salon, purpose-built software (MoeGo, Groomsoft, Teddy, Square Appointments…) already does booking, pet records, deposits, and *compliant* SMS reminders for roughly $20–$150/month with zero maintenance. That is very hard to beat with a custom app you'll maintain in your spare time.
- **If you want to build anyway, Lovable is a legitimate, good choice** — and the one I'd pick among AI builders for a non-developer: it generates a full-stack web app (React front end + Supabase database/auth + hosting) from prompts, and you can export the real code to GitHub. Pro is $25/month.
- **Four things the ads won't say:** (1) it builds websites/mobile web apps, not native iOS/Android apps — there is no App Store output; (2) the credit-based pricing means real iteration costs more than the $25 sticker; (3) security research on vibe-coded apps is genuinely bad — 91% of audited deployed ones had at least one vulnerability; (4) the moment your sister depends on it, you are her IT department.
- **For a salon, the right surface is a mobile-friendly web app / PWA anyway, not a native app.** Clients click a link from Instagram or Google; nobody downloads an app store app for one salon. That neutralizes Lovable's biggest weakness.
- **My recommendation:** put her on off-the-shelf grooming software as the baseline now; if you build, make it a Lovable project that ships as a PWA and has to *earn* replacing the baseline. Budget ≈ $25–50/month + ~$12/year domain + Stripe transaction fees, plus one security review before real client data goes in.

## 1. "Should I use Lovable?"

Short answer: **Lovable is real and good at what it does — but what it does may not be what "booking app for my sister's salon" needs first.**

What Lovable actually is (verified against its docs and multiple independent 2026 comparisons):

- An AI app builder that turns plain-English prompts into a **full-stack web app**: React front end, Supabase-backed database/auth/storage/hosting ("Lovable Cloud"), one-click publish, visual editing, and **two-way GitHub sync** so you own and can export the code.
- **Pricing:** Free tier is a trial (5 build credits/day, capped ~30/month). Pro is **$25/month** ($21/month billed annually) with 100 credits/month; Business is $50/month. Since a June 2026 billing change, one credit balance pays for building *and* hosting *and* in-app AI, so the real monthly cost depends on how much you iterate.
- It runs a mandatory pre-publish security scan — helpful, but not a substitute for a real security review (see below).
- Ads: Lovable is heavily funded and markets to everyone, so you see it everywhere. The ads are a signal of marketing spend, not of fit for your specific job. Independent 2026 comparisons do consistently rank it first for full-stack MVPs by non-developers, so it's not hype — it's just not the whole decision.

**Four caveats the ads don't tell you:**

1. **It cannot build a native mobile app.** Lovable's own docs say it is a web-only platform; it does not generate React Native, and publishing always ends at a web URL. (The Lovable phone app is for building *from* your phone — your app's users still get a website.) If you eventually need a store listing: PWA first (fine), a Capacitor wrapper second (risky — Apple's guideline 4.2 rejects thin "repackaged website" apps), or rebuild the screens in React Native/Expo against the same Supabase backend (the "real" route, more work).
2. **The cost is the credits, not the plan.** Booking apps need a lot of iteration. Heavy prompt sessions burn credits fast; top-ups are $0.30/credit on Pro. Budget $25–50/month realistically, not $25 once.
3. **Security is the risk you're least equipped to see.** A 2026 large-scale study of vibe-coded applications collected 9,041 apps and audited 200 publicly deployed ones: **91% contained at least one vulnerability, 65.77% of findings were Critical/High**, concentrated in access control, injection, and auth failures. Your app will hold client names, phones, addresses, pet data, and payment-adjacent flows. This is fixable — but it needs someone who knows what row-level security is to check the work *before* real customers use it.
4. **You become the vendor.** When it breaks at 8am on a Saturday with a full grooming schedule, there's no support line — there's you. Off-the-shelf software has support, and your sister has a fallback.

Verdict: use Lovable if the goal includes "I want to build this" — it's the best fit in its category for a first-time builder. Don't reach for it because ads made it feel like the default way to give your sister bookings; for that goal, start with the comparison below.

## 2. Buy vs. build: what off-the-shelf gives you

Grooming-specific software already solves: online booking + calendar, pet profiles and grooming notes, SMS reminders (the vendor deals with carrier registration for you), deposits and no-show policies, packages/memberships, intake forms, before/after photos, and even route optimization for mobile grooming.

2026 prices (check current before committing):

| Option | Price | Notes |
|---|---|---|
| **MoeGo** | Salon: $79 / $149 / $239 per location/month (Basic/Growth/Ultimate). Mobile grooming: $49 / $99 / $159 per van | The grooming-industry default; deepest feature set; SMS caps by tier drive the real cost |
| Groomsoft | ~$29.95/month shops, ~$39.90/month mobile | Cheaper, plainer; older interface |
| GroomBoard | $19 (Solo) / $39 (Salon) | Flat pricing; SMS allowances included |
| Teddy | ~$49 flat, unlimited texting | Aimed at text-heavy solo groomers |
| Square Appointments | Free tier; paid from ~$49/month | Smart if she already uses Square for payments |
| DaySmart Pet | from ~$29/month; two-way texting from ~$149 | Wider pet-business suite |

Rule of thumb: if her booking process today is "phone, texts, Instagram DMs, and a paper book," any middle row above is a bigger upgrade than a custom app — for less than a day of your setup time, and it keeps working when you're on holiday.

## 3. If you build: the tools I'd pick, and why

**Builder: Lovable ($25/month).** It's the most opinionated AI builder in exactly the right way for you — auth, database, and payments are wired up by default, there's a visual editor for small changes, one-click publishing, and GitHub export so you're never locked in. Alternatives and when they'd win: **Bolt.new** if you want framework freedom or intend to go React Native/Expo later (it documents Expo workflows); **v0 (Vercel)** if you mainly want polished React UI and have a developer helping; **Replit** if your long-term goal is growing into coding. For a first full-stack build by a non-developer: Lovable.

**Database, auth, file storage: Supabase** (Lovable Cloud runs on it). Why: Postgres + auth + row-level security + file storage (pet photos!) in one service. Free tier is genuinely usable during development (2 projects, 500 MB database, 5 GB egress, 50k monthly users; free projects pause after 7 days of inactivity — fine while building, not for launch). Pro is $25/month when it's real. Row-level security (RLS) is what stops client A from reading client B's data — make it an explicit checklist item, because it is the #1 documented failure in vibe-coded apps.

**Payments: Stripe** (standard US rate 2.9% + 30¢ per successful online card charge). Why: deposits at booking and cancellation policies are how salons actually kill no-shows, and Stripe Checkout keeps you out of PCI scope. Never store card numbers in your database — that's the one mistake that turns a hobby app into a liability.

**Reminders: this is the part you should NOT reflexively build.** Sending business text messages from your own app to US numbers requires **A2P 10DLC registration** with the carriers: a Brand (one-time $4 as a Sole Proprietor) + a Campaign (one-time $15 vetting + $2/month), approval typically under a week, documented opt-in, and — since June 30, 2026 — public privacy policy and terms URLs. It's doable, but it's paperwork standing between you and every "your dog is ready" text. Email via a service like Resend is easy and free at small scale. My pick: leave SMS to her off-the-shelf tool for now, build email first, add 10DLC only if the custom app carries real volume.

**Hosting: Lovable's built-in hosting** (covered by plan credits) — simplest. If you export the code and deploy on Vercel instead, note that Vercel's free Hobby plan is explicitly **non-commercial only**: a business app needs Pro at $20/month. Custom domain ≈ $12/year.

**The mobile surface: mobile web + PWA.** Add a web app manifest + service worker (Lovable can do this) so clients get a home-screen icon and app-like feel from the link she posts. iOS caveat: web push on iOS only works after the user manually adds it to the home screen (iOS 16.4+) — irrelevant if you stick to SMS/email reminders. **Only if a store listing is truly non-negotiable:** rebuild in React Native with Expo against the same Supabase backend and ship via EAS Build; budget App Store $99/year + Google Play $25 one-time, plus review time. For one salon, that is almost certainly not worth it.

**What I would NOT add: a third-party booking engine.** Cal.com looks tempting, but in 2026 its hosted API requires paid plans, its open-source fork (Cal.diy) is self-host-only and explicitly not recommended for production by its own maintainers, and its old API v1 was retired in spring 2026. For a single salon's rules, modeling availability directly in your own Postgres table — with a unique constraint that makes double-booking impossible — is simpler and more controllable.

## 4. The features that actually matter (define them before you prompt)

AI builders are great at screens and tables and weakest at exactly the logic a booking system lives on. Write these rules down *with your sister* before prompting, or you'll get an app that looks done and is subtly wrong:

1. **Availability with buffers.** Slot length depends on service (bath vs. full groom) and dog size/condition, plus cleanup time between dogs. Double-booking prevention must be enforced by the database, not just the UI.
2. **Recurring appointments.** Grooming is cyclical (every 4–8 weeks). Rebooking at checkout is the single highest-value flow for her revenue.
3. **Deposits / no-show policy.** Optional Stripe deposit per service type; clear cancellation window.
4. **Reminders.** Confirmation at booking + day-before. (See the SMS note in §3.)
5. **Pet + client profiles.** Breed, weight, temperament, matting notes, allergies, vaccination dates, before/after photos, grooming history.
6. **Intake form** for new clients and a **waitlist** (cancellation filling is real money).
7. **Groomer view.** Mobile-friendly day calendar for whoever is holding the clippers, plus a simple "today" list.
8. **Fallback.** A printable day sheet. If the app is down, the salon still runs.

## 5. Money and time (realistic)

| Item | Buy path | Build path |
|---|---|---|
| Upfront | $0 | Your time (10–40 hours to first useful version) |
| Monthly software | ~$20–$150 | Lovable $25–50 + Supabase $0 → $25 when launched for real |
| Domain | included / $0–20 | ~$12/year |
| Payments | per transaction | per transaction (Stripe 2.9% + 30¢) |
| SMS | included in most plans | A2P 10DLC ≈ $4 + $15 + $2/month when you get there |
| Native stores | n/a | $99/year Apple + $25 Google — only if you go native |
| Security review | n/a | 1–2 paid developer days before real client data |

The honest comparison isn't "$25/month vs. $79/month." It's "$79/month and it works with support," vs. "$30/month and you are on the hook forever." If building is also a learning project you value, that's a fair trade. If building is a chore you're doing to save $50/month, it is not a good trade.

## 6. Guardrails (if you build)

- **Ship order:** prototype → show your sister → fix it with her → pilot with 5 friendly clients → security review → *then* real bookings. Don't cut this line.
- **Security, concretely:** turn on and verify RLS on every table; test with a second fake client account that it can't read anyone else's rows; keep API keys server-side (never in the front end); let Stripe handle all card data; collect only data you actually need; read what Lovable's pre-publish scan flags and fix it.
- **Ownership:** wire GitHub on day 1; keep a monthly export/backup ritual.
- **Reliability:** free Supabase projects pause after a week of inactivity (fine in dev, never launch on Free); know how to restore a backup; keep the paper fallback.
- **Kill criteria:** if the app isn't saving her time or money within ~3 months of pilot, fold the functionality back into her off-the-shelf tool and keep the Lovable project as a portfolio piece. That's a win, not a failure.

## 7. Suggested next steps

1. **(This week)** Shadow her booking process for 45 minutes: how bookings arrive, appointments per day, no-show rate, who books, what she hates.
2. **(This week)** Start a trial of MoeGo or Square Appointments as the comparison baseline — seriously, this is the yardstick your custom app must beat.
3. **(Next 2 weeks)** If you're building: free Lovable account; build the three core screens (client booking flow, groomer day view, pet profile); iterate twice with your sister watching. Upgrade to Pro only when the free credits choke you.
4. **(Weeks 3–8)** Pilot the build as a PWA with real clients, in parallel with the baseline. Get 1–2 days of developer review for security before any real customer data goes in.
5. **(Week 8+)** Decide with data: does the app beat the baseline on her time saved? If yes, migrate. If no, keep the baseline — you've lost nothing but $50 and a few weekends.

## Bottom line

The ads aren't lying about Lovable — it's one of the best tools of its kind, and exactly the right pick if you want to build something this year. But the salon doesn't need an app for its own sake; it needs bookings that don't get lost, reminders that go out, and money that doesn't evaporate to no-shows. Off-the-shelf grooming software delivers that today for the price of a couple of grooms a month. Build the Lovable app *because you want to build it* — as a shadow project that has to earn the right to replace the baseline. That's how your sister gets great booking and you keep the fun of the project.

---

*Facts checked Oct 17, 2026: Lovable pricing and platform docs (docs.lovable.dev, lovable.dev/guides — web-only, no native output; Free: 5 build credits/day capped ~30/month; Pro $25/month; single credit balance since June 2026). Supabase pricing (Free: 2 projects, 500 MB DB, 5 GB egress, 50k MAU, 7-day inactivity pause; Pro $25/month). Vercel fair-use docs + terms (Hobby = non-commercial only; Pro $20/month). Stripe standard pricing 2.9% + 30¢. Twilio A2P 10DLC docs (mandatory registration for US business SMS; Sole Proprietor: $4 brand + $15 campaign vetting + $2/month; ~1 week approval; privacy policy/T&Cs required for new campaigns since June 30, 2026). Apple $99/year, Google Play $25 one-time. MoeGo, Groomsoft, GroomBoard, Teddy, DaySmart, Square Appointments 2026 pricing from industry roundups. arXiv 2606.23130 — "Understanding the (In)Security of Vibe-Coded Applications" (9,041 apps collected; 200 deployed audited; 91.0% ≥1 vulnerability; 65.77% Critical/High). Cal.com docs and Cal.diy README (hosted API on paid plans; open-source fork self-host only, not production-recommended; API v1 retired spring 2026).*
