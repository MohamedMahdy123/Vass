# Vess — Flutter

A Flutter port of the **Vess** AI digital wardrobe design doc
(`Vess.dc.html` on the Desktop).

## Running

```bash
flutter run -d chrome     # web
flutter run -d windows    # desktop
flutter test              # 8 tests
flutter analyze
```

Fonts (Instrument Serif, Geist, Geist Mono) are loaded from Google Fonts by
`web/index.html`, mirroring the design doc. **On Windows desktop they will fall
back to a system font** — bundle them under `assets/` if desktop matters.

## Layout

```
lib/
  theme/tokens.dart      Every colour from the design doc's `T` object,
                         light + dark, as a ThemeExtension. Read via
                         `context.vess`.
  theme/app_theme.dart   ThemeData assembly + the serif/eyebrow text helpers.
  models/closet_item.dart
  data/mock_data.dart    The 15-piece closet, onboarding copy, insights.
  state/app_state.dart   ChangeNotifier: theme, closet, builder, chat.
  widgets/common.dart    Swatch, VessCard, VessChip, buttons.
  screens/               One file per screen.
```

## What's real vs. faked

The design doc is a prototype and this port keeps its honesty:

- **The AI is not real.** The stylist returns canned replies on a timer, and
  "AI fill" picks the first item per slot. There is no model behind either.
- **There is no photography.** Every garment renders as the design's 152°
  gradient, built from the `a`/`b` colours on each item.
- **There is no backend.** State is in memory and resets on reload. Sign-in
  accepts anything and navigates on.

## Screens

Built: splash, onboarding, login, register, body scan, home, closet, item
detail, outfit builder, stylist, profile.

Not yet built (present in the design doc): add item, camera scan, today's
outfit, outfit rating, history, calendar, wishlist, shopping, notifications,
settings. The Profile menu rows for Calendar / Wishlist / Shopping / History
are inert placeholders.
