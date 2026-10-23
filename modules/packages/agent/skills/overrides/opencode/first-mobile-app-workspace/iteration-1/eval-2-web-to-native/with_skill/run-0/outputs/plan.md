# From Lovable Web App to Installable App With Push Notifications

## Where you are

You've already done the hardest part. The path to a first mobile app is: validate cheap on web first, then decide whether a real app is needed. Your Lovable app with ~40 weekly users is that validation — the idea works, the workflow works, and now people are asking for the next thing unprompted. Inbound requests for an installable app with push notifications are the strongest signal you can get.

You're at the decision point now. Here's how to make it correctly.

## 1. Pin down the actual demand first (a few days)

Before touching any builder, ask all ~40 users directly. A short form works; one topic per question:

- Would you actually install it today — or is the website good enough day to day?
- What do you want push notifications for? Reminder before a game night, a new night announced, changes/cancellations, "who's coming" updates?
- iPhone or Android? This decides whether you can start with one platform.
- What should the app do that the website can't? (Widget with the next game night, etc.)

This separates "we need notifications for events" from "an app would feel more real." Those two answers lead to very different decisions, and this check costs you days, not weeks.

## 2. The decision: build the real mobile app

The decision rule: the web version decides. Web good enough — stay web. Web blocked by real mobile needs — installed app, notifications, widgets, camera, store presence — go real. Your users are asking for two things on that list by name, so the answer is: go real.

Your options, honestly stated:

- Wrapper (Capacitor, Despia): fastest path to installable with push, but it's a shortcut, not a destination. Use only as a stopgap if you must have notifications live next week.
- React Native: solid cross-platform choice; most AI builders support it. The pragmatic fallback.
- Native (Swift + Kotlin): where the market is moving and the best long-term answer. AI collapsed the development cost, so this is realistic even without specialist developers. The default recommendation.

Set two expectations:

- Expect a full rebuild, not a port. That's fine — a rebuild is far easier than the first build, because you already know exactly what to build and which features matter.
- Keep the web app running while you build. Your 40 users shouldn't notice a transition.

## 3. Map the app flow by flow (before any code)

Sketch each flow on paper using your web app screenshots as reference. Browse mobbin.com to see how real apps structure them.

- Onboarding (new users)
- Registration / sign-in — your existing 40 already have accounts; plan a smooth first login
- Core product: game night list/calendar, RSVP, roster, history (usually several flows inside)
- Notifications: reminders, new-night announcements, changes — the reason you're doing this
- Monetization — optional at the start; skip if the app stays free
- Anything the survey surfaced (widgets, etc.)

## 4. Write the PRD, flow by flow

Co-write it with Claude. This is the context you hand to the AI builder. Without a PRD the agent guesses; with one it builds your plan. One flow = one spec + screenshots.

## 5. Choose a builder — three checks

1. Pricing model: prefer tools that let you plug in your own AI agent or subscription (Claude, Cursor) over per-credit billing. You'll maintain this app for years; per-credit costs compound.
2. Code ownership: you must always be able to take your code free. Some tools gate exports behind expensive plans. Check before you invest anything.
3. Feel: try it. Comfort compounds across months of iteration.

Native preference: pick a tool that produces both iOS and Android from one project, ideally native Swift and Kotlin. If the survey shows nearly everyone is on one platform, you can start there and expand later. If no available tool clears the three checks at that bar, React Native + Expo is the pragmatic fallback.

## 6. Build flow by flow

One flow = one spec + screenshots, one prompt cycle at a time. Never ask for the whole app in one prompt.

- Full-time: a week or two for an app this size.
- Side-project pace (a few hours a day): one to two months. That's fine.
- Budget ~30% of the time for debugging and verification.

## 7. Test and release fast

- TestFlight (Apple Developer Program, $99/year) to your 5–7 most engaged users first, then the rest of your 40. Collect feedback from each person individually.
- Google Play: $25 one-time registration. New personal accounts need a closed test — 12 testers for 14 days — before public release; your group satisfies that easily.
- Ship free. Pricing is optional at the start; monetize later, if ever.

The faster you release, the faster you learn. Ship feature by feature.

## One question to settle along the way

Is this a tool for your group, or the start of a product for board game groups everywhere? Both are valid. If it's the second, write the PRD for strangers rather than your friends, and study how groups organize today to find the angle where you're much better. Your traction already proves the core loop works.
