# Ogera CRM Design System

The visual language behind Ogera CRM, extracted from the screens already shipped (Login, Contacts, Employees, Lead Followup, Lead Preview, Tasks, and every modal/drawer around them). Its job is to stop every new screen from re-deriving colors, type sizes and button styles from scratch — pull from here instead, and only add a new token when nothing here fits.

## Brand feel

Ogera CRM reads as calm, professional and green-anchored — a deep forest green (`brand-deep-green`) for identity and headings, a brighter working green (`accent-green`) for anything a user clicks or needs to notice, and everything else kept to neutral grays on a soft off-white canvas. No gradients, no shadows-for-decoration, no saturated accent colors outside the one accent green and the handful of semantic pill colors below. Corners are consistently rounded (never sharp, never pill-everywhere) and borders are hairline, not heavy.

## Typography

Two font families, both loaded from Google Fonts:

- **Sora** — all headings (`h1-page-title` 28/36 700, `h2-section-title` 22/30 700, `h3-panel-title` 17/24 700, `card-title` 14.5/20 700). Sora is also used for the logo wordmark and any large numeric stat.
- **DM Sans** — everything else: body copy, form labels, table cells, buttons. Scale: `body-md` 13.5/20 500 (default paragraph/table text), `body-sm` 12.5/18 500 (secondary/helper text), `label` 12/16 600 (form field labels, uppercase-tracking section labels), `caption` 11.5/16 500 (timestamps, fine print), `button-label` 13.5/20 600 (all button text).

Rule of thumb: if it's a title a user scans for, it's Sora/bold; if it's something a user reads or types, it's DM Sans.

## Color

**Primary button** — fill `accent-green` (#0E7A4F), white text, `radius-md` (8px), `button-label` type, `space-8`–`space-12` vertical padding. This is the only solid-fill color in the system; reserve it for the one primary action per screen/modal (Save, Add New, Submit).

**Secondary button** — white fill, `border-strong` (#DEE1E5) 1px border, `text-body` (#3A3E4A) text, same radius/type as primary. Used for Cancel, Filter, Export, and any button that isn't the primary action. On hover/selected variants (icon-grid pickers, dropdown items) the border becomes `accent-green` and the background washes to `accent-green-tint-08` or `-06`.

**Destructive** — text/icon `danger` (#B42323) on `danger-bg` (#FDECEC) where a background is needed; otherwise plain `danger` text on white (Delete, Remove).

**Semantic pills** (contact type, activity type, priority, status) each pair a light tint background with a saturated text/icon color of the same hue family — see `tokens.json` for every pair (Consumer/Partner/Dealer; WhatsApp/Call/Field/Message/Note/Quotation; High/Medium/Low/No priority; To do/In Progress/Completed). Never invent a new hue for a new category — pick the closest existing pair, or extend this file with a matching light-tint/saturated-text pair.

Full token list with hex values and usage notes: `tokens.json`.

## Layout surfaces

- **Page background** `body-bg` (#F3F6F4) behind everything.
- **Sidebar** always white (`surface-white`), never the brand green — `border-default` right edge, active nav row gets `accent-green-tint-08` background + inset left accent bar + `text-heading` color.
- **Cards / table rows / inputs**: white surface, `border-default` 1px, `radius-md`/`radius-lg`.
- **Center modals** (Add Contact, New Task, New Activity Log, New Schedule Followup): dimmed `overlay-backdrop`, white card max-width ~520–560px, `radius-modal` (16px), `shadow-modal`, sticky footer with Cancel (secondary) + primary action right-aligned.
- **Right drawers** (Lead Preview, Add Contact Drawer): same dimmed backdrop, panel flush right, max-width ~440–480px, `shadow-drawer`.
- **Dropdown menus** (Stage/Assignee change): absolute panel below the trigger button, white, `border-strong`, `radius-lg`, `shadow-dropdown`; selected item gets `accent-green-tint-08` background + `text-heading` + bold.
- **Empty states**: centered icon badge (52×52px, `radius-xl`, `surface-muted` background, `text-faint` icon) + bold `text-body` heading + `text-muted` subtext (max-width ~250px) — the triggering action button (e.g. "+ Log New Activity") stays visible above the empty state, never hidden by it.

## Components in this system

- `components/Button` — primary, secondary and destructive button states.
- `components/Pill` — the semantic pill/badge pattern shared by contact-type, activity-type, priority and status tags.

## How to use this when building a new screen

1. Start every new screen from the white-sidebar shell already in `Contacts.dc.html` — don't rebuild the sidebar/nav per screen.
2. Pick type styles and colors from `tokens.json` by name, not by eyeballing a hex from an old screen.
3. New status/category? Add one pill pair here first, then use it everywhere that category appears.
4. If a layout pattern (modal, drawer, dropdown, empty state) already exists above, reuse its exact spacing/radius/shadow — don't introduce a slightly different variant.
