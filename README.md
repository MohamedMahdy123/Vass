# Vess — Dress with intention

An AI fashion & wardrobe app built with Flutter + Supabase. Vess turns your
closet into an active personal stylist: capture your clothes, get outfit
recommendations, compose looks, plan them onto a calendar, and get reminded
what to wear.

## Features

- **Digital closet** — batch-capture pieces; AI auto-tags category, colour,
  fabric, occasion & season (background cut-outs for a clean product-shot look).
- **AI Stylist chat** — ask in plain language ("what should I wear to a date
  tomorrow?"); replies are grounded in *your* wardrobe and come with **tappable
  action cards** that deep-link to the exact outfit, item, or screen.
- **Outfit Canvas & My Outfits** — compose looks head-to-toe and save them
  (persisted per user).
- **Virtual try-on** — preview how a look reads on you (styling preview).
- **Smart Outfit Scheduler** — pick a date + occasion, the app styles a look
  from your closet, plans it on the calendar, and sets a reminder notification.
- **Calendar planner, Wishlist, History, and Shopping** (wardrobe-gap analysis).

Demo-first: the app is fully usable offline with no keys. Cloud features
(auth, AI, persistence, notifications) light up when Supabase + provider keys
are configured.

## Run

```bash
flutter pub get
flutter run           # or: flutter run -d chrome
```

## Build an Android APK

CI builds it automatically — see `.github/workflows/build-apk.yml`
(Actions → Build Android APK → download the `vess-release-apk` artifact), or
locally:

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Tech

Flutter 3.7 · Dart 2.19 · Provider · Supabase (Postgres + Edge Functions) ·
flutter_local_notifications.
