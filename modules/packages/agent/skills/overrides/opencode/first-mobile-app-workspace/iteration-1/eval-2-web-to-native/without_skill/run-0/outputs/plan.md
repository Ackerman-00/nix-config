# From your Lovable web app to an installable app with push notifications

## The short answer

You do **not** need to rebuild anything native. Your existing Lovable app can become an installable app with push notifications in a couple of weekends, for roughly $0, by turning it into a **PWA (Progressive Web App)** and adding **web push**:

- **Android and desktop:** installs from the browser (icon on home screen, full-screen window), push notifications work.
- **iPhone:** also installs (Share → Add to Home Screen), and push works — with one catch: iPhone users only get notifications **after** they add the app to their home screen (iOS 16.4+). There is no push for a plain Safari tab.
- One codebase, instant updates, no App Store review, no developer fees.

Only if, after that, the group still wants "the real app in the App Store", wrap the same web app with **Capacitor** and ship it to the stores — do not rewrite it. A native rewrite (React Native / Flutter) means weeks of work and a second codebase to maintain, for zero real benefit at 40 users.

## Why this fits your situation

- 40 weekly users is a friend group, not a market. The main reason to be in app stores is discovery — you already hand everyone the link.
- What people are actually asking for is almost certainly "an icon on my phone" and "remind me about game night". A PWA delivers both.
- You keep building in Lovable at your current speed. Store apps need review for every update; a PWA ships the moment you publish.
- Cost: PWA is $0 extra. Store apps are $99/yr (Apple) + $25 (Google) + build tooling + review cycles, plus ongoing upkeep.

## What "installable + push" looks like on each platform

| Platform | Install | Push notifications |
|---|---|---|
| Android (Chrome) | Automatic "Install app" prompt once the PWA is set up, or menu → "Add to Home screen" | Yes, even in-browser; best after install |
| iPhone (Safari, iOS 16.4+) | Share → Add to Home Screen → keep "Open as Web App" on (iOS 26+) | Only after install; permission must be requested inside the installed app |
| Desktop (Chrome/Edge) | Install from the address bar | Yes |

Honest iOS caveats, worth telling the group up front:

- A Safari tab can never receive push on iPhone; it has to be the home-screen version.
- Apple requires the permission prompt to appear from a user tap (button), not automatically on load.
- There will be some drop-off at the install step. A short in-app guide ("iPhone: tap Share → Add to Home Screen") recovers most of it.

## The three routes (and when each is right)

### Route 1 — PWA + web push on your existing app (recommended now)

Add a manifest, a service worker, and a push subscription flow. Nothing about your current app changes; you add files alongside it. Most of this Lovable can generate for you, and everything runs on the Supabase backend your app likely already uses.

Effort: a few hours for installability; about a weekend for push + reminders. Cost: $0 at your scale (Supabase free tier; push delivery itself is free — it uses the browser's built-in Web Push protocol).

### Route 2 — PWA with a hosted push service (least maintenance)

- **OneSignal**: free plan covers far more than 40 users (10,000 web push subscribers; even the stricter 2026 free-plan limits only cap mobile push at 1,000 monthly active users). Dashboard for sending/scheduling, and it automatically cleans up dead subscriptions — a chore the roll-your-own route leaves to you. It also later works for Capacitor/native with the same account.
- **Progressier**: a no-code PWA + push toolkit with a Lovable-specific quickstart; from about $15–25/month. Good if you never want to touch files.

### Route 3 — Store apps via Capacitor (only if the group genuinely insists)

Wrap the same web app in a native shell and publish to both stores. Real native push via OneSignal's official Capacitor SDK. Costs and caveats:

- Apple Developer Program $99/year, Google Play $25 one-time; you need a Mac (or a cloud macOS build service) for iOS builds.
- Apple guideline 4.2 rejects "a website in a shell" apps — you must add genuine native value (offline, push, calendar sync, share sheet) or it may be rejected.
- New Google Play personal developer accounts must run a closed test with 12 testers for 14 consecutive days before production. Your 40 users can fill that easily; organization accounts are exempt.
- Do this because you *want* store presence — not because a wrapped web app notifies better. It is the same app underneath.

And what not to do: a full native rewrite (React Native/Flutter). Weeks of work, a second codebase forever, and your Lovable workflow is gone — for a 40-person hobby app.

## Step-by-step plan

### First, 10 minutes of homework

Ask the group two questions: (1) iPhone or Android? (2) Which notifications do you actually want — "night tomorrow" reminder, "new night posted", "spot opened up"? The phone split tells you how much the iOS install flow matters; the answers tell you which notifications to build first.

### Weekend 1 — Make it installable

1. **Export your code to GitHub.** In Lovable: Settings → GitHub → connect (Git sync is available on all plans, and it protects you from lock-in whatever you do next).
2. **Add the PWA layer** — either ask Lovable ("Convert this app into an installable PWA: manifest, icons, service worker, install banner") or add it via your own editor:
   - `public/manifest.json`: name, short_name, icons (192px + 512px), `display: "standalone"`, theme color, start_url.
   - Service worker registration + a light cache of the app shell (vite-plugin-pwa is the standard tool if you're editing the Vite project directly).
   - Icons in `public/icons/`.
3. **Add a "Get the app" banner in the app.** Android users see a one-tap Install button (the `beforeinstallprompt` event); iPhone users see a short illustrated "Share → Add to Home Screen" guide.
4. **Publish and test on real phones** (one Android, one iPhone). Simulators do not show install prompts or push. Verify: icon, full-screen launch, the iOS instructions match what users actually see on iOS 26 ("keep Open as Web App on").
5. **Hosting:** your lovable.app URL already has HTTPS and is fine for this. A custom domain on Lovable requires a paid plan; alternatively host the exported code on Cloudflare Pages/Netlify (free tiers) with your own domain. HTTPS is mandatory — you already have it either way.

### Weekend 2 — Push notifications

Pick one:

**A. Hosted (OneSignal or Progressier).** Add their snippet after the PWA setup, trigger their permission prompt from a button, send a test. Fastest path, and they handle the unglamorous parts (dead subscriptions, delivery quirks, but — note — even with a hosted service the iPhone still must install the app first).

**B. Free, all inside Supabase (what the standard walkthrough does):**

- Generate VAPID keys: `npx web-push generate-vapid-keys`. Public key in the frontend, private key as a Supabase secret.
- `push_subscriptions` table: `user_id`, `subscription` JSONB, plus row-level security so users only touch their own rows.
- Subscribe flow: user taps "Enable notifications" → `Notification.requestPermission()` → `pushManager.subscribe()` → save subscription to Supabase.
- `send-push` Edge Function using the `web-push` npm package.
- Service worker `push` and `notificationclick` handlers to display the notification and open the right screen.

Then wire up the sends:

- **Scheduled reminder** — "Game night tomorrow at 7" via Supabase Cron (pg_cron + pg_net) calling your send function; or OneSignal's built-in scheduler.
- **Event notifications** — "New game night posted" / "A spot opened up" via a Supabase database trigger.
- **Hygiene** — delete subscriptions that return 410/404 so the list stays clean.

### Two cheap wins worth doing alongside

1. **Calendar feed (ICS):** a subscribe-once calendar link for upcoming nights. About two hours of work, zero permissions, works for every phone — arguably the most reliable "don't miss it" channel you can ship.
2. **Email fallback** (Resend or Supabase email) for people who won't install, and keep the group chat as belt and braces for the weekly reminder.

### Weeks 3–4 — Measure, then decide

Track three numbers: share of weekly users who installed, share who enabled push, reminder click-through. If install rate is low, treat it as an onboarding problem — usually it's the iOS instructions. Only if the group is still asking for "the real app" after a month of this should you go Route 3 (Capacitor).

## Notification design (keep it minimal)

Event-driven plus one reminder is plenty. Resist more:

- "Game night tomorrow, 7pm at [place]. 2 spots left." → opens the event
- "New game night posted" → opens RSVP
- Optional: "A spot just opened up for tomorrow"

Add a per-category toggle in settings so people can mute reminders without deleting the icon. Never send notifications that don't pass the "would a friend say this out loud?" test.

## Costs, side by side

| Path | One-off | Recurring |
|---|---|---|
| PWA + Supabase web push | $0 | $0 (free tier; domain ~$12/yr if you leave lovable.app) |
| PWA + OneSignal | $0 | $0 at 40 users |
| PWA + Progressier | $0 | ~$15–25/month |
| Capacitor store apps | Apple $99/yr + Google $25 | build tooling if no Mac; maintenance for two stores |
| Native rewrite | weeks of work | two codebases forever |

## Gotchas

- Never request notification permission on first load. Ask right after someone RSVPs or creates a night — the moment it's obviously useful.
- The permission prompt is one-shot. One accidental "Don't allow" costs you that device forever.
- On iPhone, push does not exist until the app is on the home screen. Write the instructions for iOS 26, including "leave Open as Web App on".
- Test under the **published** URL, not a preview — service workers behave differently there.
- Don't over-cache in the service worker; never cache session or user data.
- If you edit code in both GitHub and Lovable, sync conflicts happen — edit in one place at a time.
- Push is a nudge, not a guarantee. The calendar feed and group chat stay as your safety net.
- Everything above is the same app. Never fork the web app and the "app" version.

## Bottom line

This weekend: GitHub sync, PWA, install guide. Next weekend: web push (OneSignal if you want easy, Supabase if you want free), a "night tomorrow" reminder, and an ICS calendar feed. Revisit store apps only if people still want them a month from now — and even then, wrap with Capacitor, don't rewrite.

## Key facts verified (October 2026)

- iOS web push requires adding the web app to the Home Screen (iOS 16.4+); iOS 26 has an "Open as Web App" toggle when adding, and it must stay on. Sources: Apple Support ("Turn a website into an app in Safari"), WebKit blog, OneSignal iOS web push docs.
- Lovable: Git sync available on all plans; custom domains require a paid plan. Source: docs.lovable.dev (GitHub integration, custom domain).
- OneSignal free plan: 10,000 web push subscribers; 2026 free-plan changes cap mobile push at 1,000 MAU — both far above 40 users. Source: onesignal.com/pricing and related posts.
- Google Play: personal developer accounts created after Nov 13, 2023 need 12 testers for 14 consecutive days of closed testing; organization accounts are exempt. Sources: multiple 2026 guides (Testerbee, ontests.app).
- Apple guideline 4.2 ("minimum functionality") still rejects thin web wrappers in 2026. Source: 2026 App Store review write-ups (Capgo, wanilla.co).
- Supabase Cron (pg_cron + pg_net) can schedule Edge Functions for reminders. Source: supabase.com docs ("Scheduling Edge Functions") and Supabase Cron pages.
