---
name: first-mobile-app
description: Use when building, planning, or shipping a first or early-stage mobile app - mentions of making an app from an idea, validating an app idea, choosing a mobile stack (native Swift/Kotlin, React Native, Flutter, wrapper), writing a PRD for an app that will run on a phone, App Store or Google Play release, TestFlight testing, or going from app idea to shipped app. Use even when the user doesn't say "first" - applies to any non-developer or beginner building a mobile app with AI, and to advice about mobile app production workflow. Not for web-only apps, browser dashboards, or tools that never target a phone store.
---

# First Mobile App

## How to use this skill

Follow The Path below in order, step 1 through step 8. Do not skip steps 1-3 (idea, web validation, native decision) even if the user only asks about tools or code - every step before code exists to prevent building the wrong app.

## Overview

Step-by-step path for building a first mobile app, distilled from an agency/studio operator who shipped 100+ apps and ~6M organic downloads since 2009, adapted for the AI-vibe-coding era. Core principle: **validate cheap before building real**. Ideas die in validation, not in code. The most expensive mistake is building a native app for an idea nobody wants.

## The Path (8 steps)

### 1. Define exactly what you are building

Two ways to pick an idea - both valid, know which one you're on:

- **Own pain:** you have the problem, you build the fix. Innovation path. Higher risk, harder, needs heavy validation investment.
- **Validated category:** pick a category you like, study every competitor, find the angle where you can be much better (your insight, your approach, AI). Demand is pre-proven; pricing, reviews, and complaints are visible. Cheaper to validate.

### 2. Prototype and validate on web first (1-2 weeks)

- Two days on the prototype, then a full week with real users.
- Fastest path: mobile **web** version - Lovable, Replit, Claude chat, Codex, or whatever you already pay for. The tool barely matters; it just has to produce a clickable web app fast.
- Questions to answer: Is the idea interesting? Does the workflow make sense? Which features to include vs drop?
- Talk to target users directly; a questionnaire works (one founder got 100+ replies in the crowded period-tracker category and still found her angle).
- Expect to pivot often or drop the idea entirely. That is the point - learn it before spending real mobile effort.

### 3. Decide if you need a real mobile app

- **Stay web** if the web version is good enough. Do not build native because it feels like "real".
- If it must be installed:

| Option | Verdict |
|---|---|
| Wrapper (Capacitor, Despia) | Fast, but temporary. A shortcut, not a destination. |
| React Native | Solid cross-platform choice; most AI builders support it. Native now rivals it since AI cut dev cost. |
| Native (Swift + Kotlin) | Where the market is moving. Best long-term answer. More complex, worth it. |

Tiebreak rule: the web version decides. Web good enough = stay web. Web blocked only by install-ability + push notifications = try an installable web app (PWA) first - add-to-home-screen and web push work on Android in-browser and on iPhone once added to the Home Screen - before committing to a rebuild. Web blocked by deeper native needs (widgets, camera, background tasks, store presence) = go native.
Why native wins now: AI collapsed development cost, so full native no longer requires two specialist devs - a non-technical person can build it.
Expect a **full rebuild** from web to native. Rebuild is far easier than the first build - you already know exactly what to build and which features matter.

### 4. Map the app flow by flow

Before any code, sketch how the app looks on mobile - paper or whiteboard. Ask what differs from the web version.

Split everything into flows:
- onboarding
- registration
- monetization
- core product (usually several flows inside)

Describe and sketch every flow using web-version screenshots as reference. Add mobile-specific: notifications, widgets, camera, whatever applies. Browse [mobbin.com](https://mobbin.com) to see how real apps structure these flows.

### 5. Write the PRD

Product requirements document, flow by flow. This is the context you hand to the AI builder. Co-write it with your AI model of choice (Claude, Codex, ChatGPT, Gemini - whatever you use). Without a PRD the agent guesses; with one it follows the plan.

### 6. Choose a builder - three checks

1. **Pricing model:** prefer tools that let you plug in your own AI agent or subscription (Claude, Codex, Cursor, or similar) over per-credit billing. You will maintain this app for years - per-credit costs compound. Cheapest option that works usually wins; this is a long play.
2. **Code ownership:** you must always be able to take your code free. Some tools gate exports behind expensive plans. Check before you invest anything.
3. **Feel:** try it. Comfort compounds across months of iteration.

Native preference: if iOS and Android are both needed, pick a tool that produces both platforms, preferably native Swift and Kotlin from one project. If no available tool fits that bar on the three checks above, React Native + Expo is the pragmatic cross-platform fallback.

### 7. Build flow by flow

One flow = one spec + screenshots, one prompt cycle at a time. **Never ask for the whole app in one prompt.**

- Full-time effort: a week or two for an average app. Side-project pace, one to two months - fine, most people build a few hours a day.
- Budget ~30% of total time for debugging and verification.

### 8. Test and release fast

- Apple Developer Program: $99/year; send builds via **TestFlight**.
- Google Play: $25 one-time registration; new personal accounts need a closed test (12 testers for 14 days) before public release.
- Test with **5-7 real people** before any release; collect feedback from each individually.
- No testers? Release free and learn from real App Store users.
- Pricing optional at the start - ship free, monetize later.

The faster you release, the faster you learn. Ship feature by feature.

## Common Mistakes

| Mistake | Correction |
|---|---|
| Building native before validating | Web prototype + real users first (steps 2-3) |
| Asking for the whole app in one prompt | Flow by flow, spec per flow |
| Skipped PRD | The AI invents the product instead of building yours |
| Per-credit billing on a long-lived app | Own-agent tooling on your own subscription |
| Plan that can't export code free | Verify ownership before starting |
| Waiting for polish to release | TestFlight at 5-7 users, ship the version |
| No testers lined up | Release free, learn from real store users |
| Native rebuild for install+push alone | Check the PWA middle option (step 3) before rebuilding |

## Provenance

Distilled from a guide by a studio operator who shipped 100+ apps (popappfactory, ~6M organic downloads) since 2009, posted to r/vibecoding (Oct 2026). Adapted for AI-agent era; vendor-specific tool names reflect that guide's examples, verified against 2026 sources for store requirements ($99/yr Apple, Xcode 26 builds, 12-tester Google Play closed testing).
