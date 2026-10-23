# Your habit tracker: from zero code to both app stores

*A step-by-step plan for a first-time builder — October 2026*

## The honest version first

You can absolutely do this without ever "learning to code" the way a computer science student does. In 2026 the work looks different: you direct an AI assistant that writes the code, you test the app on your own phone, and you handle the store paperwork. People ship small apps like this all the time.

But be clear-eyed: it's a project, not a weekend. For a habit tracker, plan on roughly **2–4 months of part-time work** for your first version, about **$124 in the first year** in unavoidable fees, and a real chunk of that time spent on testing, store requirements and marketing — not on code. The code is the part AI helps with most.

Also: a habit tracker is a good first app, because it can work fully offline. No accounts, no server, no sync, no privacy headaches. Version 1 should keep everything on the phone.

## 1. Pick how you'll build it (the one big decision)

**Path A — AI-assisted build with a cross-platform framework (recommended).** Use Expo, a free toolkit that makes one codebase run on both iPhone and Android. You describe features to an AI coding assistant (ChatGPT, Claude, Cursor, Copilot — whichever you prefer); it writes the code; you open the app on your own phone in seconds with the free "Expo Go" app. Cost: $0 to start. You'll pick up basic builder skills along the way — running commands, saving versions, reading error messages — and the AI coaches you through each one. You do **not** need a Mac: iPhone builds happen on Expo's cloud builders.

**Path B — No-code app builders.** Tools like Adalo, Thunkable, Draftbit and FlutterFlow let you assemble screens by dragging pieces together. Faster to your first screen; usually costs a monthly subscription (typically tens of dollars or more — check current pricing); you can hit the limits of the tool; some handle store publishing for you. Good if you truly want zero terminal. Trade-offs: less control, ongoing cost, and switching later means rebuilding.

**Path C — Hire a developer.** For even a small app, think thousands of dollars minimum. You'd still manage the stores, testing and marketing yourself. Only worth it if you have budget and a validated idea.

This plan assumes Path A. Steps 5–10 apply no matter which path you choose.

## 2. The plan, in order

### Step 1 — Decide what Version 1 is (one evening)

Write down the smallest version worth shipping. For a habit tracker, a good v1: add/edit/delete habits; check one off each day; see your streak; one daily reminder per habit; a simple stats screen. Explicitly **not** in v1: user accounts, cloud sync, sharing, social features, home-screen widgets (surprisingly tricky), Apple Watch apps. Every extra feature means days of work — and you can always add later.

Do this too: install 2–3 popular habit trackers (Streaks, Habitica, Loop, Fabulous...) and read their 1- and 2-star reviews. That's free market research: it tells you what annoys users and where you can do better.

### Step 2 — Set up your computer (half a day)

Any Windows, Mac or Linux laptop works. You do **not** need a Mac. Install Node.js (the "LTS" version) and VS Code (a free code editor). Create a free account at expo.dev. Install the free **Expo Go** app on your phone. Recommended: also create a free GitHub account to back up your project.

Then, in your AI assistant, ask: *"Walk me through creating a new Expo app and running it on my phone with Expo Go, step by step, assuming I've done nothing like this before."* Your daily working loop from then on: AI edits the code → you save → your phone updates automatically. That loop is the whole game.

### Step 3 — Build the app in thin slices (the biggest chunk of the calendar)

Build in this order, with each slice testable on your phone the same day:

1. Show a list of habits (fake data first).
2. Add, edit, delete habits.
3. Tap to check off a habit for today.
4. Save data between launches (a small database right on the phone).
5. Streak logic.
6. Daily reminder notifications.
7. Stats screen (a calendar heat map or simple bar chart).
8. Polish: icon, colors, dark mode, empty states, a little animation or sound.

Rules of the road: keep every change small; test on a real phone constantly; when something breaks, paste the full error message to your AI before changing anything; save after each working feature. Things breaking constantly is normal — that, plus fixing them, *is* the work.

One practical note: create the project with the newest Expo SDK, and update it again before you submit — the stores periodically require apps built with the latest tools (Apple, for example, now requires apps built with the iOS 26 SDK), and staying current on Expo keeps you compliant automatically.

### Step 4 — Test like a stranger (1–2 weeks)

- Install it on family or friends' phones; watch them use it without your help.
- Try to break it: airplane mode, no notification permission, changed time zone, force-quitting mid-action, huge text sizes, dark mode.
- Compare iPhone vs Android quirks (notifications and back gestures differ between them).
- Fix the worst 10 annoyances; write down everything else for version 1.1.

### Step 5 — Enroll with Apple and Google (start early — the waiting is out of your control)

**Apple Developer Program — $99/year.** You need an Apple Account (your Apple ID) with two-factor authentication and your legal name; sometimes a quick identity check. Enroll at developer.apple.com/programs. Approval is usually within a day or two, but can take longer. Enroll as an individual unless you have a registered company — organization accounts need extra paperwork.

**Google Play Console — $25 once.** Register at play.google.com/console; identity verification can take days. Critical detail: personal developer accounts must run a **closed test with at least 12 testers who stay opted in for 14 continuous days** before you may even apply for production access. That application is then reviewed (usually within about 7 days) before you can publish. Start this clock as early as you can — and start recruiting your 12 testers now.

### Step 6 — Prepare your store listing (a weekend)

- **Icon:** one 1024×1024 image. Make it yourself with a free design tool, or generate one.
- **Screenshots:** 4–8 per platform, in the exact sizes each console lists. You can frame them in a phone mockup for free.
- **Text:** app name (check it's not already taken in either store), short and long descriptions, keywords. Write for a human first — but do put the obvious words ("habit tracker", "streaks") in the title and description.
- **Privacy policy:** both stores require a link, even for an app that collects nothing. For a local-only app it's a short page ("data stays on your device; we collect nothing"). Host it anywhere public (GitHub Pages, Notion, any site builder).
- **Support contact** (email or page), plus Google's "Data safety" form and Apple's "App Privacy" questionnaire. Local-only app = "no data collected" — that's a selling point; say so.

### Step 7 — Ship to Apple

1. Create the app in App Store Connect (a bundle ID like `com.yourname.habittracker`).
2. Build and upload from any computer using Expo's tools (`eas build`, then `eas submit`). Let EAS generate and manage your signing certificates when it asks — this used to be the scary part; it's automated now.
3. Install it from **TestFlight** (Apple's beta service) on your own phone and clean up anything embarrassing. Internal testers get builds instantly; outside testers need a brief review.
4. Submit for App Review with a short reviewer note explaining what the app does. Reviews often finish in a day or two. First submissions frequently get one rejection — read the exact reason, fix it, resubmit. This is a normal loop, not a failure.
5. Release manually once approved, or automatically — your call.

### Step 8 — Ship to Google

1. Create the app in Play Console; fill in the listing, the Data safety form and the content rating.
2. Build the Android file (`.aab`) with `eas build` and upload it, or use `eas submit`.
3. **Internal testing** first: just you and a few people; builds become available quickly.
4. **Closed test:** your 12+ testers opt in and stay opted in for 14 continuous days. Recruit a few extras — anyone who drops out restarts their own 14-day clock. (Can't find 12 people? There are paid tester-matching services — vet them and make sure the testers are real people who actually use the app.)
5. After the 14 days, apply for production access from the Play Console dashboard; the application is reviewed (usually ≤7 days), then your app goes through its own review.
6. Release.

### Step 9 — Launch, then keep going

- Release quietly, then widen. Watch the crash dashboards in both consoles.
- Reply to every review. Ship fixes in small updates — most code-only fixes can go out over the air (no new review) with Expo.
- The hard part is not building — it's being found. Pick a niche ("a habit tracker for new runners" beats "another habit tracker"), post honest updates while you build, and record a 30-second demo video for the store pages and social posts.

### Step 10 — Money (later, once v1 is stable)

- Start free. Add paid features once real people use the app.
- Digital purchases must use the stores' billing systems (set up subscriptions/products in both consoles; tools like RevenueCat make cross-store subscriptions manageable).
- The stores take a cut: Apple 30% (15% via the free-to-join App Store Small Business Program — you qualify under $1M/year), Google Play roughly 15% on your first $1M/year (30% above). Auto-renewing subscriptions generally qualify for about 15% on both.
- You'll file tax and banking details in each console; both stores pay out monthly.

## 3. What it costs

| Item | Cost |
| --- | --- |
| Apple Developer Program | $99 / year |
| Google Play Console | $25 one-time |
| Expo + EAS Build | $0 (free tier: 15 iOS + 15 Android cloud builds/month, slower queue; $19/mo optional for faster queues) |
| AI coding assistant | $0–$20+/month, depending on what you use |
| Optional: domain + hosting for privacy policy / support page | ~$0–$15 / year |
| Optional: icon / screenshot design help | $0 (DIY) to ~$150 |
| **First-year total** | **~$124 + optional extras** |

Your real investment is time: 5–10 hours a week for 2–4 months is a realistic pace for a first app.

## 4. What trips up almost every first-timer

1. Feature creep — you'll be tempted to add "just one more thing". Don't; ship small.
2. Expecting to pass review on the first try — budget one rejection and its fix.
3. Skipping the privacy policy or data-safety forms — an easy, avoidable rejection.
4. Testing only on your computer — real phones behave differently.
5. Starting with accounts and sync — huge complexity, zero value to a v1 user.
6. Ignoring Google's 12-testers-for-14-days rule — it can silently cost you a month.
7. Treating launch as the finish line — updates, reviews and support are the ongoing job.

## 5. Your checklist

- [ ] Write the v1 feature list; read competitors' bad reviews.
- [ ] Install Node.js + VS Code; make an Expo account; install Expo Go on your phone.
- [ ] Build the app in slices; test on a real phone daily.
- [ ] Have friends and family try it; fix the worst bugs.
- [ ] Enroll: Apple ($99/yr) and Google ($25) — start early.
- [ ] Prepare icon, screenshots, descriptions, privacy policy.
- [ ] TestFlight yourself → submit to Apple review.
- [ ] Play internal test → closed test (12 testers × 14 days) → production access → release.
- [ ] Launch; watch crashes; answer reviews.
- [ ] Update regularly; consider monetization once stable.
