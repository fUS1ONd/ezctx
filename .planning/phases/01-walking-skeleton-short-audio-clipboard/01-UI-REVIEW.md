---
phase: 1
slug: walking-skeleton-short-audio-clipboard
audited: 2026-05-17
baseline: 01-UI-SPEC.md
screenshots: not captured (Flutter app — no web dev server)
---

# Phase 1 — UI Review

**Audited:** 2026-05-17
**Baseline:** 01-UI-SPEC.md (approved design contract)
**Screenshots:** Not captured — Flutter app, no web dev server running

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 3/4 | Core CTAs match spec; "Из файлов" button label absent; "Проверить ключ" CTA missing; double SnackBar on copy |
| 2. Visuals | 2/4 | BLOCKER: Settings screen double title; upload card missing dashed border + "Из файлов" button; processing file card uses GlassCard (r-card) instead of GlassTile (r-tile); icon library spec not followed |
| 3. Color | 3/4 | Token system solid; GlassIconBtn icon color sources from Material theme not inkPrimary token; second BoxShadow missing from GlassCard |
| 4. Typography | 3/4 | 4 sizes and 2 weights correctly defined; PrimaryButton uses SizedBox(width: 8) not AppSpacing.sm; heading style lacks letterSpacing token |
| 5. Spacing | 3/4 | AppSpacing tokens used throughout; upload card 260px min-height constraint absent; PrimaryButton gap raw 8px not AppSpacing.sm |
| 6. Experience Design | 2/4 | No pulseDot animation on active pipeline step; no screen transition animation (default Material slide); cancel button is plain TextButton not glass pill; settings missing status card; double copy feedback (button + SnackBar redundant) |

**Overall: 16/24**

---

## Top 3 Priority Fixes

1. **BLOCKER — Settings screen double title** — Both `AppTextStyles.heading` "Настройки" (line 68) and `AppTextStyles.display` "Настройки" (line 72) render on screen simultaneously, separated by only 32px. Users see two stacked headings reading "Настройки / Настройки" — a clear visual defect. Fix: remove the `Text('Настройки', style: AppTextStyles.heading)` from the header Row on line 68; the back arrow alone is sufficient navigation context, matching the pattern used in `processing_screen.dart` and `result_screen.dart`.

2. **WARNING — Upload card missing dashed border and "Из файлов" button** — The spec defines the upload card drop-zone with a dashed border at `rgba(255,91,58,0.55)` accent color and an explicit "Из файлов" pill-button inside the card. The implementation uses a plain GlassTile wrapping the icon+text with no dashed border and no separate button label — the entire tile is a GestureDetector. Fix: wrap the upload icon container in a `DashedBorder` custom painter or use `CustomPaint` with a dashed stroke in accent color at 0.55 opacity; add a pill-shaped "Из файлов" label below the format hint text.

3. **WARNING — No pulseDot animation on active pipeline step; cancel button not glass pill** — The spec requires `pulseDot` (1.2s ease-in-out infinite) on the active pipeline dot during transcription and a floating glass-sheen pill container for the bottom bar (elapsed time + cancel button). The implementation uses a static `Container` with a flat `AppColors.accent` circle and a bare `TextButton` with label-styled text. Fix: wrap the active dot in an `AnimatedBuilder` with a looping `AnimationController` (1200ms) that scales/fades the dot; wrap the bottom bar in a `GlassCard` with pill `borderRadius: AppRadius.pill` to contain both the elapsed `MonoText` and the cancel action.

---

## Detailed Findings

### Pillar 1: Copywriting (3/4)

**PASS — Core CTA strings match spec:**
- `home_screen.dart:157` — "Транскрибировать" ✓
- `home_screen.dart:195` — "Выберите файл" ✓
- `home_screen.dart:198` — "mp3, wav, m4a, ogg, flac · до 19 МБ" ✓
- `result_screen.dart:124` — "Скопировать" / "Скопировано" ✓
- `processing_screen.dart:289` — "Отменить обработку" ✓
- `home_screen.dart:65` — "Добавьте API-ключ" dialog title ✓
- `home_screen.dart:74` — "Перейти в настройки" ✓
- `api_keys_screen.dart:255` — "Получить ключ на console.groq.com" ✓
- Delete confirmation dialog matches spec ✓

**WARNING — Missing "Из файлов" button label inside upload card:**
Spec (Screen 1): "кнопки «Из файлов»" inside the upload card. Not present in `home_screen.dart`. The entire tile acts as a tap target but the label is absent.

**WARNING — "Проверить ключ" CTA missing:**
Spec states: "кнопки «Проверить ключ» / «Удалить»" on API keys screen. `api_keys_screen.dart` only has "Добавить ключ" and delete. No "Проверить ключ" button or key-validation flow exists.

**WARNING — Double copy feedback:**
`result_screen.dart:63-66` fires a SnackBar("Скопировано") AND the button label changes to "Скопировано". Spec only defines the button state transition. The SnackBar is redundant and creates two simultaneous "copied" signals.

**WARNING — Copywriting in SnackBar for console.groq.com link:**
`api_keys_screen.dart:249-251` — link tap fires a SnackBar with raw URL text instead of launching a browser. Spec says the link should navigate to `console.groq.com`. The UX degrades to copying the URL mentally — not described in the contract.

---

### Pillar 2: Visuals (2/4)

**BLOCKER — Settings screen double title (visual bug reported by user):**
`settings_screen.dart:68` renders `Text('Настройки', style: AppTextStyles.heading)` inside the header Row alongside the back button.
`settings_screen.dart:72` renders `Text('Настройки', style: AppTextStyles.display)` as the page display title 32px below.
Result: two "Настройки" headings visible simultaneously — a clear implementation error. No other screen duplicates its title this way. ProcessingScreen (line 141) and ApiKeysScreen (line 166) put the screen name ONLY in the header row at heading size; they do not repeat it as a display-size heading. SettingsScreen was written differently and created this collision.

**WARNING — Upload card drop-zone: no dashed border:**
Spec: "иконка upload (72×72px, border-radius 22px, dashed border accent 0.55 opacity)". `home_screen.dart:177-184` — the upload icon container uses `AppGradients.accent` fill (solid), no dashed border. The spec-required dashed accent stroke around the drop zone is absent.

**WARNING — Upload card: no tap-scale animation:**
Spec interaction states: "Pressed / tap → Scale 0.97, subtle shadow". `home_screen.dart:137-145` — `GestureDetector` wraps the tile with `onTap` only. No `onTapDown`/`onTapUp` with `AnimatedScale` or `Transform.scale`. The upload tile feels unresponsive compared to the spec.

**WARNING — Processing screen file card uses GlassCard (r-card=22px) not GlassTile (r-tile=30px):**
Spec Screen 2: "Карточка файла (glass sheen, r-tile)". `processing_screen.dart:148` uses `GlassCard` which defaults to `borderRadius: AppRadius.card` (22px). The file card should be a `GlassTile` (30px) to match the spec's r-tile designation.

**WARNING — Icon library: Material Icons used, not lucide_flutter/phosphor_flutter:**
Spec Design System: "Icon library: lucide_flutter або phosphor_flutter". All icons throughout the codebase use `Icons.*` (Material Icons). `pubspec.yaml` lists no lucide or phosphor dependency. This is a spec deviation though the visual impact is moderate — Material icons are similar in style.

**WARNING — Settings screen missing status card:**
Spec Screen 4: "Status card (glass sheen, r-tile): аватар-иконка (48×48px), статус «Подключено к Groq», модель + good dot". `settings_screen.dart` has no status card — the screen jumps directly from the title to the API-ключи ListTile. The connection-status indicator is absent entirely.

**WARNING — GlassCard missing second BoxShadow:**
Spec Glass Surface: two shadows: `0 10px 24px rgba(20,10,30,0.10)` AND `0 1px 2px rgba(20,10,30,0.06)`. `glass_card.dart:49-55` has only the first shadow. The micro-shadow (`blurRadius: 2, offset: Offset(0,1)`) is absent, making glass edges slightly less defined than specified.

---

### Pillar 3: Color (3/4)

**PASS — AppColors token system correctly defined:**
All spec color values verified in `design_tokens.dart`:
- `accent: Color(0xFFFF5B3A)` ✓
- `accentGradientStart: Color(0xFFFF8A4D)` ✓
- `good: Color(0xFF2DB585)` ✓
- `bad: Color(0xFFE0395A)` ✓
- `inkPrimary: Color(0xFF1A1421)` ✓
- `inkSecondary: Color(0x9E1A1421)` ✓ (0x9E/255 ≈ 0.616, within rounding of 0.62)
- `inkTertiary: Color(0x611A1421)` ✓ (0x61/255 ≈ 0.380)
- `inkDivider: Color(0x141A1421)` ✓ (0x14/255 = 0.078 ≈ 0.08)
- `glassSurface: Color(0x7AFFFFFF)` ✓ (0x7A/255 ≈ 0.478 ≈ 0.48)
- `glassDeep: Color(0xA8FFFFFF)` ✓ (0xA8/255 ≈ 0.659 ≈ 0.66)

**PASS — Accent color usage constrained to declared elements:**
Accent applied on: CTA button gradient, copy button gradient, logo icon, upload icon, shimmer bar, pipeline active dot, "Заменить" text label, console link. No rogue accent use found on decorative elements.

**WARNING — GlassIconBtn icon color uses Material theme, not inkPrimary token:**
`glass_icon_btn.dart:46` — `color: Theme.of(context).colorScheme.onSurface`. The `EzCtxApp` ThemeData in `app.dart` does not configure `colorScheme`, so Material 3 auto-generates a colorScheme from the default seed color. This may produce a slightly off-brand purple-tinted icon color rather than `AppColors.inkPrimary (#1A1421)`. Fix: `color: AppColors.inkPrimary`.

**WARNING — PrimaryButton disabled gradient uses hardcoded greys:**
`primary_button.dart:54-58` — disabled state uses `Color(0xFFB0B0B0)` and `Color(0xFF888888)`. Spec says disabled: "Opacity 0.38, gradient серый". The current approach combines a grey gradient with 0.38 opacity, which technically achieves the spec intent, but the hardcoded grey hex values are not registered tokens. Acceptable but not ideal.

---

### Pillar 4: Typography (3/4)

**PASS — Exactly 4 sizes and 2 weights defined in AppTextStyles:**
- display: 34px w700 letterSpacing -1.2 height 1.08 ✓
- heading: 20px w700 height 1.2 ✓
- body: 16px w400 letterSpacing -0.16 height 1.5 ✓
- label: 13px w400 height 1.3 ✓
- mono: 13px w400 RobotoMono ✓

**PASS — All screens use AppTextStyles or `.copyWith()` from tokens. No rogue fontSize/fontWeight found in UI files.**

**WARNING — PrimaryButton label uses `AppTextStyles.heading.copyWith(color: Colors.white)` — correct size/weight but heading style has no letterSpacing defined:**
The spec does not explicitly define button text letterSpacing, so this is a minor gap rather than a violation.

**WARNING — `SizedBox(width: 8)` raw pixel in PrimaryButton:**
`primary_button.dart:99` — `const SizedBox(width: 8)`. This should be `AppSpacing.sm` (8.0) for consistency with the token system. Functionally identical but violates the "use tokens" convention.

**WARNING — Heading style missing letterSpacing token:**
Spec Typography: all sizes have letter-spacing. display has `-0.035em`. body has `-0.01em`. heading (20px) has no letter-spacing in the spec table, but the pattern of declining spacing by size suggests it should be approximately -0.02em (-0.4px). Currently absent from the heading TextStyle.

---

### Pillar 5: Spacing (3/4)

**PASS — AppSpacing tokens used consistently across all screens:**
Verified in: home_screen, processing_screen, result_screen, settings_screen, api_keys_screen. All EdgeInsets and SizedBox calls reference AppSpacing constants.

**WARNING — Upload card min-height 260px not enforced:**
Spec Spacing Scale exception: "Карточка загрузки (upload card) минимальная высота: 260px". `home_screen.dart:139-145` — `GlassTile` wrapping the upload content has no `ConstrainedBox` or `constraints` enforcing minimum height. On small phones the card may render shorter than specified if the content is insufficient. Fix: wrap `GlassTile` in `ConstrainedBox(constraints: BoxConstraints(minHeight: 260))`.

**WARNING — Raw 8px gap in PrimaryButton instead of AppSpacing.sm:**
`primary_button.dart:99` — `const SizedBox(width: 8)`. Should be `const SizedBox(width: AppSpacing.sm)`. Minor but a spacing token violation.

**PASS — Touch targets:**
`glass_icon_btn.dart:30-31` — `SizedBox(width: 44, height: 44)` wraps the 36×36 glass button, meeting the 44px minimum. PrimaryButton height is 52px. GestureDetector on GlassTile covers the full tile area.

**INFO — Bottom safe area:**
Spec requires `MediaQuery.of(context).padding.bottom` + 32px for the floating cancel button. Processing screen uses `const SizedBox(height: AppSpacing.lg)` (24px) at the bottom, without dynamic safe-area padding. On phones with navigation bars this may clip the cancel button.

---

### Pillar 6: Experience Design (2/4)

**PASS — Loading states present:**
- `home_screen.dart:186-191` — `CircularProgressIndicator` overlaid on upload icon during file picking ✓
- `processing_screen.dart:189-192` — `ShimmerBar` shown during `TranscriptionLoading` ✓
- `api_keys_screen.dart:103-105` — `CircularProgressIndicator` for key list loading ✓

**PASS — Error states present:**
- `home_screen.dart:147-153` — validation error text in bad color ✓
- `processing_screen.dart:297-316` — error message + retry PrimaryButton ✓
- `processing_screen.dart:318-335` — missing-key state with navigation CTA ✓
- `api_keys_screen.dart:227-235` — field-level error message ✓

**PASS — Confirmation for destructive action:**
`api_keys_screen.dart:78-99` — Delete key shows AlertDialog "Удалить ключ? Это действие нельзя отменить." with "Отмена" / "Удалить" (bad color) ✓

**BLOCKER — No pulseDot animation on active pipeline step:**
Spec Animations: "pulseDot: 1.2s infinite, ease-in-out, Active pipeline step". `processing_screen.dart:262-277` — the active dot is a static `Container` with `AppColors.accent` fill. No `AnimationController`, no scale/opacity animation. The pipeline looks visually inert during transcription.

**WARNING — Screen transitions use default Material route animations:**
Spec Animations: "Screen transitions: 300ms easeInOut". `app.dart` uses `routes:` map with `MaterialPageRoute` (default), which uses a slide-from-right transition ~300ms but is not the spec-defined easeInOut fade. No `onGenerateRoute` with `PageRouteBuilder` is configured.

**WARNING — Cancel button is a plain TextButton, not a glass pill floating bar:**
Spec Screen 2: "Floating bottom bar (glass sheen, pill): elapsed time (mono, Body 16px) + кнопка «Отменить обработку» (bad color, pill)". `processing_screen.dart:281-294` uses a `Column` with a plain `Text` and `TextButton`. No glass surface, no pill shape, no contained floating bar. The elapsed time and cancel text are unstyled.

**WARNING — Settings screen missing status/connection card:**
Spec Screen 4: "Status card (glass sheen, r-tile): аватар-иконка (48×48px), статус «Подключено к Groq», модель + good dot". This card is entirely absent from `settings_screen.dart`. Users have no visual feedback on API connection status from the settings screen.

**WARNING — Double copy feedback is redundant:**
`result_screen.dart:63-66` shows SnackBar "Скопировано" simultaneously with the button changing to green "Скопировано" state. The spec only defines the button state transition. The SnackBar adds noise — both signals fire at the same time for the same action.

**WARNING — Empty state for result screen if _args is null:**
`result_screen.dart:73-74` — renders `Scaffold(body: SizedBox.shrink())` with no gradient background and no error message. If navigation arguments are missing, the user sees a blank white screen briefly before `popUntil` fires. Fix: return a `GradientBackground`-wrapped `Scaffold` even for the blank fallback.

---

## Registry Safety

Registry audit: shadcn not initialized (Flutter project, not web). No third-party blocks checked. N/A per UI-SPEC Registry Safety table.

---

## Files Audited

- `/root/projects/ezctx/lib/ui/app.dart`
- `/root/projects/ezctx/lib/core/constants/design_tokens.dart`
- `/root/projects/ezctx/lib/ui/screens/home_screen.dart`
- `/root/projects/ezctx/lib/ui/screens/processing_screen.dart`
- `/root/projects/ezctx/lib/ui/screens/result_screen.dart`
- `/root/projects/ezctx/lib/ui/screens/settings_screen.dart`
- `/root/projects/ezctx/lib/ui/screens/api_keys_screen.dart`
- `/root/projects/ezctx/lib/ui/widgets/glass_card.dart`
- `/root/projects/ezctx/lib/ui/widgets/glass_tile.dart`
- `/root/projects/ezctx/lib/ui/widgets/glass_icon_btn.dart`
- `/root/projects/ezctx/lib/ui/widgets/gradient_background.dart`
- `/root/projects/ezctx/lib/ui/widgets/primary_button.dart`
- `/root/projects/ezctx/lib/ui/widgets/shimmer_bar.dart`
- `/root/projects/ezctx/.planning/phases/01-walking-skeleton-short-audio-clipboard/01-UI-SPEC.md`
