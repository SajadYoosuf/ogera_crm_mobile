# Ogera CRM Mobile — Design System Translation

**Purpose:** how the web design system in `README_DESIGN_SYSTEM.md` maps onto the Flutter app. Web is the source of truth for brand; this file decides where mobile must deviate (touch, thumb reach, small screens) and records the gaps that still need a decision.

**Status:** draft for review. No code has been changed yet.

---

## 1. Audit: where mobile and web disagree

| Area | Web system (README) | Mobile today (`lib/theme/`) | Gap |
| --- | --- | --- | --- |
| Primary action | `accent-green` `#0E7A4F`, white text | `OgeraColors.blue` `#126BB0` (Material `FilledButton`) | Wrong hue. Action color is blue on mobile, green on web. |
| Brand anchor | `brand-deep-green` for identity and headings | `ink` `#0B2942` (navy) for headings | Navy is not in the web palette. |
| Login hero | Deep forest green | `forest` `#0E4D3A`, but the login button renders near-black (per `Main@1x.png`) | Three different "primary" colors on one screen. |
| Canvas | `body-bg` `#F3F6F4` | `canvas` `#F1F5F7` (cool blue-gray) | Close, but not the same. |
| Borders | `border-default` / `border-strong` `#DEE1E5` | `line` `#D6E0E6` | Close. Pick one and reuse. |
| Body text | `text-body` `#3A3E4A` | `ink` `#0B2942` for body | Mobile body text is navy, web is neutral gray. |
| Typography | Sora (headings) + DM Sans (everything else) | No `google_fonts`, no `fontFamily`. Platform default (Roboto/San Francisco) | Mobile does not use the brand fonts at all. |
| Type scale | `body-md` 13.5, `body-sm` 12.5, `label` 12, `caption` 11.5 | Material defaults (14–16 body) | Web sizes are too small for thumb-held phones. Keep the roles, not the sizes. |
| Button radius | `radius-md` 8 px | `fieldRadius` 12 px for buttons and inputs | Mismatch. |
| Card radius | `radius-lg` / `radius-xl` | `cardRadius` 16 px | Roughly aligned. |
| Button height | Padding-based (`space-8`–`space-12`) | 52 px filled, 48 px outlined | Fine on mobile. Keep. |
| Shadows | None for decoration; modal and drawer shadows only | `cardShadow` and `lowShadow` on cards | Acceptable if limited to floating surfaces. Remove from plain list cards. |
| Pills | Light tint bg + saturated text pairs | Not audited in this pass | Needs a check against `tokens.json`, which does not exist in the repo. |

**Missing from the repo:** `tokens.json`, `components/Button`, `components/Pill`, and `Contacts.dc.html`, all referenced by the web README. Mobile cannot pull from them until they exist or are exported. Treat the table above as the working source until then.

---

## 2. Decisions needed before building (recommendations)

1. **Action color.** Recommend: `accent-green #0E7A4F` for primary buttons, selected nav, and links. Keep navy `ink` for headings only. Retire `blue` as an action color (keep it for info chips at most). This makes login, the hero, and the buttons one family.
2. **Body text.** Recommend: neutral `text-body #3A3E4A` for body, `text-heading` for titles. Stop using navy for paragraphs.
3. **Fonts.** Recommend: add Sora and DM Sans through `google_fonts` (or bundled `.ttf` assets so the app works offline). Sora for titles, DM Sans for everything else. If the team prefers no new dependency, use the platform font and record it as a deliberate deviation.
4. **Button radius.** Recommend: buttons at 8 px to match web, inputs at 12 px. Keep cards at 16 px. Change `filledButtonTheme` and `outlinedButtonTheme` only.

---

## 3. Web → mobile pattern map

The web patterns assume a mouse and a wide screen. On a phone, reach and one-handed use decide the pattern.

| Web pattern | Mobile equivalent | Why |
| --- | --- | --- |
| Center modal (Add Contact, New Task, New Activity, New Schedule) | **Full-screen page** for forms with more than 3 fields; **bottom sheet** for 1–3 fields | Keyboard takes half the screen. A centered modal gets pushed off-screen. Full-screen pages keep the sticky action bar visible. |
| Right drawer (Lead Preview, Add Contact Drawer) | **Full-screen push** (detail) or **bottom sheet at 85% height** (quick preview) | Drawers have no horizontal room on a phone. The existing `BottomSheetThemeData` already covers sheets. |
| Dropdown menu (Stage, Assignee) | **Bottom sheet list** with a search field when there are more than 8 items | Absolute dropdowns get covered by the keyboard and are hard to hit near the bottom of the screen. |
| Sticky modal footer (Cancel + primary) | **Bottom bar** above the safe area, inside `SafeArea`, with the primary button on the right | Same pattern. Put it where the thumb already is. |
| Sidebar nav | **Bottom `NavigationBar`**, max 5 tabs, extra items under "More" | Already in place. Keep the web's active-state rule: tint background + bold label. Drop the inset accent bar. |
| Hover states | **Pressed** state (ink ripple, slight tint) | No hover on touch. |
| Tables | **Cards or list rows** (name, phone, stage pill, due chip) | Tables do not fit 360 px wide. |
| Icon grid pickers | Same grid, minimum 48 px cells | Web cell sizes are too small for fingers. |
| Empty state | Same: icon badge + heading + subtext, **action button stays visible above** | Matches the web rule and the PRD's "one clear action". |
| Loading | **Skeletons**, not spinners (per PRD §7.2) | Matches the PRD. |
| Destructive confirm | **Confirm sheet** with a red text action and a neutral cancel | Matches the PRD. Keep the web's `danger` on `danger-bg` pattern. |

---

## 4. Mobile-specific rules (additions to the web system)

- **Touch target:** 44 px minimum everywhere (already in `OgeraSpacing.touchTarget`). Use 48 px for primary actions and icon buttons in lists.
- **Body size:** body text at 15 px minimum, secondary text at 13 px, captions at 12 px. Web sizes (13.5 / 12.5 / 11.5) are too small for phones held at arm's length. Keep the same role names.
- **Safe areas:** every bottom bar, FAB, and sheet respects `SafeArea` and the keyboard inset (`MediaQuery.viewInsetsOf(context).bottom`).
- **Keyboard:** forms scroll so the focused field stays visible. The primary action moves into the bottom bar, not under the keyboard.
- **One primary per screen:** only one filled button per screen or sheet. Everything else is outlined or text.
- **Status and category colors:** use the same pill pairs as web. Never add a new hue for a new category. Pick the closest pair, or add one pair to this file and to `tokens.json` first.
- **Dark mode:** not in scope for this pass. The web README has no dark tokens either.

---

## 5. Build order (once decisions in §2 are made)

1. Update `OgeraColors` with the web tokens (`accent-green`, `brand-deep-green`, `text-body`, `text-heading`, `border-default`, `body-bg`). Keep old names as aliases so screens do not break in one step.
2. Update `AppTheme`: primary color, button radius, body text color, text theme (fonts and sizes from §4).
3. Apply the new theme to login first (the hero, the button, the EN/മലയാളം toggle). Check it against `Main@1x.png`.
4. Roll out to Contacts, then Lead Followup, then Tasks. Replace any screen-local hex values with `OgeraColors` names.
5. Add a widget test or golden for the login screen so color drift shows up in review.

---

## 6. Open questions for the product owner

- Is `accent-green #0E7A4F` the approved mobile action color, or should mobile keep blue?
- Are Sora and DM Sans approved as mobile fonts, and can the app add them as bundled assets?
- Should `tokens.json` and the component specs be exported from the web project so mobile and web read the same file?
