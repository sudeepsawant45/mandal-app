# UI redesign (blue "Ganpati Mandal" theme)

STATUS: **written, NOT compiled, NOT analyzed, NOT run.** The authoring environment has no Flutter/Dart.
Run `flutter analyze` and `flutter test` (CI does this) before calling it done, and look at every screen on a phone.

## What changed
Shared look (applies to every screen): `lib/core/theme/app_theme.dart` (royal blue, white cards, rounded inputs/buttons,
blue app bars, white navigation bar, gold accents), plus `core/widgets/brand_widgets.dart`
(emblem, initials avatar, role badge, status pill, section header, icon badge), `otp_code_field.dart`,
and restyled `state_views.dart`, `fund_summary_card.dart`, `entry_tile.dart`.

## Screen inventory (every screen found in lib/)
| Screen | File | Status |
|---|---|---|
| Splash / session restore | auth/account_screens.dart | restyled |
| Welcome (new, shown once per launch) | auth/welcome_screen.dart | new |
| Login: email, then 6 OTP boxes, resend countdown, error box | auth/login_screen.dart | restyled, same logic |
| Profile load error / retry | auth/account_screens.dart | restyled |
| Dashboard | dashboard/dashboard_screen.dart | redesigned |
| Home shell, bottom navigation | navigation/home_shell.dart | themed |
| App menu | navigation/app_menu_button.dart | + "My profile" |
| Household donations (households, transactions) | households/donations_screen.dart | cards |
| Household detail | households/household_detail_screen.dart | themed |
| Common fund | mandal_fund/mandal_fund_screen.dart | themed |
| Visarjan (groups, history), group detail | visarjan/*.dart | cards |
| T-shirt sponsorship | tshirt_sponsorship/tshirt_screen.dart | cards |
| Entry form, entry details, entry list/filters | ledger/*.dart | themed (inputs, buttons, sheets) |
| Reports hub, report screen, PDF export/share | reports/*.dart | themed; logic untouched |
| Users | users/users_screen.dart | cards, role badge, menu |
| Audit log | audit/audit_screen.dart | cards |
| Settings (mandal name, financial year) | settings/settings_screen.dart | themed |
| My profile (new) | profile/profile_screen.dart | new, read-only (see below) |

## Not done / differs from the reference image (on purpose)
* **No Google login, no password, no phone-number OTP** - the backend only supports email OTP.
* **No "Edit profile"**: the backend has no endpoint for a member to change their own name/email
  (`PUT /api/users/:id` is admin-only and refuses self-changes). Profile is read-only and says so.
  Adding one needs a new backend endpoint (needs your approval).
* **No profile photo, no notifications bell, no notification settings, no data backup**: nothing in the backend supports them.
* **Dashboard top tiles show the Common Mandal Fund only** (income / expense / balance), labelled as such.
  The reference shows one combined total; the app rule is that funds are never added together.
* **No Ganpati artwork**: the project has no image asset, so a text emblem ("ॐ") is used. Put a real image in
  `assets/` and replace the child of `BrandMark` to use it.
* Bottom navigation keeps the existing five tabs (Home, Donations, Common, Visarjan, T-shirt), not the reference's.
* "Session expired" returns to the login screen without a banner message (not added).
* Entry form / details / report screens were not individually rebuilt; they take the new theme only.

## Checks run (second pass)
Flutter/Dart cannot be installed here (the allowlisted proxy blocks the Dart SDK download and pub.dev), so these were NOT run:
`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk`.

Run instead:
* Backend: `cd backend && npm test` -> 117 / 117 passed (includes the Dart-source API contract test).
* Syntax: every `lib/` and `test/` Dart file parsed with tree-sitter-dart (syntax only): 0 parse errors; the parser was shown to flag a deliberately broken file.
* APIs: the Flutter 3.47.7 framework source (same version CI installs, from GitHub) was grepped: every ThemeData / *ThemeData parameter used in `app_theme.dart` exists, `CheckedPopupMenuItem`, `SegmentedButton.styleFrom(selected*Color)` exist. `IconAlignment` (3.28+) is not used.
* Project imports resolve; every symbol from the new widget files is imported where used; l10n keys identical in EN/MR (243) and every `l.t('..')` key exists; no-secrets/Firebase test rules grep clean.
* Fixed during review: the dashboard quick-access grid used a fixed-height `GridView` that would overflow with two-line Marathi labels; it is now a `Wrap` of fixed-width tiles.

Not verified: type errors, analyzer lints, the new widget tests, runtime layout (overflow), any visual result. A phone/emulator and screenshots are still required.
