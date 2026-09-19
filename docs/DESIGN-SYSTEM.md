# Psałterz (Psalter) — visual design system

Implementation reference. Source: the Claude Design project („Psałterz — system wizualny
śpiewnika" (Psalter — hymnal visual design system)). This file is the single source of truth for
the code — the Claude Design project is not readable by an agent.

Overriding principle: **the song text is the interface**; the rest of the app only leads to it.
No cards, colored circles, or shadows — hierarchy is carried by typeface, spacing, and a single
accent hue.

---

## 1. Colors

Contrast is calculated against the background the element **actually sits on**, not against black.

### Dark theme (primary) — against background `#191A1D`

| Role | Hex | Contrast | Usage |
|---|---|---|---|
| background | `#191A1D` | — | screens, top bar, navigation |
| surface | `#212328` | — | search field, pressed row |
| surface +2 | `#262930` | — | dialog, sheet, snackbar |
| line | `#2E3138` | — | 1 dp hairline |
| line — index dots | `#45494F` | — | dotted leader line in a list row |
| text (warm white) | `#F4EFE6` | 15.0:1 | song text, titles |
| secondary text | `#A8A29B` | 6.8:1 | song number, descriptions |
| tertiary text | `#938F87` | 5.3:1 | inactive tab |
| accent — saffron | `#E2B872` | 9.3:1 | drop cap, uppercase labels, repeat marks, active tab |
| destructive | `#F29186` | 7.5:1 | deletion |
| favorite | `#E39AAF` | 7.8:1 | heart |

### Light theme (equal priority) — against background `#F7F4EE`

| Role | Hex | Contrast | Usage |
|---|---|---|---|
| background — bone paper | `#F7F4EE` | — | not screen white |
| surface | `#FFFDF8` | — | search field, dialog, sheet |
| pressed | `#EFEAE0` | — | feedback when a row is tapped |
| line | `#E2DCD1` | — | 1 dp hairline |
| line — index dots | `#C9C2B5` | — | dotted leader line |
| text | `#1B1A17` | 15.9:1 | ink |
| secondary text | `#5C5852` | 6.4:1 | |
| tertiary text | `#6E6A62` | 4.9:1 | |
| accent — dark saffron | `#7A5518` | 6.1:1 | |
| destructive | `#A3231B` | 6.8:1 | |
| favorite | `#8C2F4F` | 7.3:1 | |

### Other

- Scrim under a dialog: dark `rgba(0,0,0,.60)`, light `rgba(27,26,23,.45)`
- Focus: 2 dp outline in the accent color
- The accent is **one hue (saffron ≈ 40°) in two tones** — a single tone cannot hold 4.5:1
  against both backgrounds at once

### What this fixes

The current version has white digits on `#9bd8ff` = **1.5:1**. The number loses its background and
becomes secondary text on the screen background = **6.8:1**, in tabular figures.

---

## 2. Typography

Two typefaces from Google Fonts, both with full `latin-ext` (ą ć ę ł ń ó ś ź ż).

- **Newsreader** (200/300/400) — song text, titles, numbers. A serif with optical sizing;
  at 10–30 pt it keeps its rhythm and does not fall apart on diacritics.
- **Schibsted Grotesk** (400/500/600) — interface: uppercase labels, labels, buttons, navigation.
  Tabular figures.

Not Inter and not Roboto.

**Tablets** (shortest side at least 600 dp): all text is **×1.35** on top of the system text size,
because a tablet often stands on a music stand, further from the eyes. The interface text, the song
text (S × text scale; the slider still shows S) and the list rows grow with it; icons and spacing stay
in dp. The combined scale is capped at ×2.0, the largest the layouts are tested at. Implemented in
`TabletTextScale`.

### Interface scale (dp)

| Role | Size / line height | Typeface |
|---|---|---|
| screen title | 20 / 1.05 | Newsreader |
| song title in a list | 17 / 1.2 | Newsreader |
| number in a list (tabular) | 15 / 1 | Newsreader |
| dialog title | 19 / 1.3 | Grotesk 500 |
| dialog body, sheet, empty state | 15 / 1.5 | Grotesk 400 |
| text button | 15 / 1.2 | Grotesk 600 |
| tab label | 10.5 / 1 | Grotesk 500 |
| section uppercase label („Refren") | 8.5 · letter-spacing +0.26em | Grotesk 500 |

### Song text scale — proportions derived from S

`S` = the size set with the slider (10–30 pt, **default 19**). Everything else is derived from S.

| Measure | Formula | At S = 19 |
|---|---|---|
| line height | 1.62 × S | 30.8 |
| spacing between blocks | 1.26 × S | 24 |
| chorus indent | 0.74 × S | 14 |
| drop cap of the first verse | 2.16 × S | 41 |
| number of each subsequent verse | 0.74 × S | 14 |
| column side margin | 22 dp (fixed) | 22 |
| max column width | 34 × S | 646 |

Line height remains a multiplier, but the slider gets a range of **1.4–1.8** instead of 1.0–3.0
(default 1.62).

---

## 3. Song text renderer

The database provides a single string with markers. The renderer **removes the markers from the
text flow** and turns them into typography — no icons and no colored patches.

| Pattern | Meaning | Rendering |
|---|---|---|
| `^\d+\.\s` | verse number | first: drop cap 2.16 × S; subsequent: digit 0.74 × S with a line |
| `^Refren:\s` | chorus | uppercase label „Refren" with a line + indent 0.74 × S. **No italics** |
| `[: … :]` | repeat | two marks in the accent color, attached to the first and last word of the phrase — they stay with it even when the paragraph wraps |
| `\n\n` | block boundary | spacing 1.26 × S, **never empty lines** |

The data has no line breaks, and they cannot be reconstructed without errors (breaking after
punctuation fails on „Nućcie Jemu chwałę, / cześć!"). A verse flows like a paragraph
and wraps on its own.

The renderer accepts an optional `\n` inside a block — if the data ever regains its line breaks,
the same screen will start showing them without a redesign.

### Dimensions added during implementation

Two values the design did not specify but the code needed:

| Measure | Value | Rationale |
|---|---|---|
| line next to the verse digit and the uppercase label „REFREN” | `1.5 × S`, fixed | A full-width leader line means something else — in a list row it leads the eye to the song number. Repeating it in the song text is confusing, so here it is only a short dash next to the label |
| spacing between a block label and its content | `1.26 × S ÷ 3`, i.e. one third of the between-block spacing | The label should stay with its verse; full block spacing would detach it from the text |

**Unpaired repeat marks.** The data contains typos such as `[Czym prędzej
pośpiesz Doń!:]`, where the opening mark lost its colon. The parser leaves such a lone mark as
plain text instead of pretending it is a repeat.

---

## 4. Spacing and shapes

4 dp base, six values:

| Value | Usage |
|---|---|
| 4 | icon ↔ tab label |
| 8 | title ↔ favorite heart |
| 12 | field padding, spacing between actions |
| 16 | side margin of lists and bars |
| 24 | dialog padding, spacing between song blocks |
| 32 | settings blocks, empty state |

Two radii: **12 dp** (dialog, sheet, block) and **pill** (search field, button).
A list row has no radius because it has no background — a hairline separates it.

Removed: 1, 2, 10, 15, and 30 dp, along with the cards.

---

## 5. Components

**List row** — 48 dp, one variant for all three lists. Title (Newsreader 17), dotted leader
line, number at the right edge (Newsreader 15, tabular). An 11 dp favorite heart
**next to the title, not at the end of the row** — it does not get lost with a long title. User song:
uppercase label `MOJA` (Mine) instead of a number. States: resting, pressed (surface), selected
(number in the accent). The whole row is the tap target.

The title is shown **in full**: it is not truncated with an ellipsis but wraps onto further lines,
and the leader line runs from the end of the last line to the number. The row then grows vertically —
48 dp is a minimum, not a fixed height. Decided during implementation of step 5; replaces the earlier
single-line title.

**List fast scrolling** — a **6 × 48 dp** pill thumb at the right edge of the song list,
in the index-dot color, in the accent while dragging. Tap target **48 × 48 dp**: the drawing
is narrow so it does not overlap the row content, but the finger hits the full 48 dp. While dragging,
a **song number label** appears to the left of the thumb: a pill on surface +2
with a hairline, Newsreader 17, tabular figures — the same format as the number in a list row. The label
sits over the dotted leader line, never over the title or the favorite heart.

The thumb appears **only on the full list**, and only when the content is longer than two screens.
During an active search it disappears along with the label: results are short, and the song number
would not correspond to the position in the list anyway.

The thumb position is computed as a fraction of `maxScrollExtent`, and the number in the label comes
from the **first actually visible row**, not from dividing the offset by the row height — rows have
different heights and grow with the font (rules 1 and 6 in section 7).

**Search field** — 44 dp, pill, **always visible**. 15 dp magnifier, hint
„Szukaj” (Search), a clear cross when there is input (48 dp target). Focus: 2 dp outline in the accent.
A single field handles number, title and lyrics, diacritic-insensitive. The words of a query count in any order,
each from the start of a word, the longer ones by their stem („chwała” finds „chwały”). Results are ranked,
title matches first; every word found is highlighted in the title. A query of digits lists by number.

**Moving between songs** — the song text is a page, and going to the previous or next song turns it,
as in a book; it is not opening something new. Only the text moves, horizontally, across the full width;
the top bar and the song bar **stay put** and only change their number and title. No fade, scale or
parallax. While the page turns, a **hairline** in the line color marks the seam between the two songs,
like the edge of a sheet of paper; at rest it is not drawn. A swipe follows the finger 1:1 and on release finishes the turn or springs back (a flick, or a
drag past half the width), on a stiffer spring than the platform default: critically damped, mass 0.5,
stiffness 300, so the page settles in about **0.45 s** instead of 0.9 s, without overshooting. The song
bar arrows turn the page in **200 ms** with the Material 3 **emphasized decelerate** easing
`Cubic(0.05, 0.7, 0.1, 1)` (`Durations.short4`, `Easing.emphasizedDecelerate`): a quick start that lands
softly. The next song comes in from the right, the previous one from the
left. „Przejdź do numeru” (Go to number) opens the song **without animation**: that is opening the book at
a page, not turning through the pages in between. With reduced motion (system setting) the arrows switch
without animation too. On iOS a swipe that starts at the left edge stays the system "back to the list"
gesture; only swipes that start away from the edge turn the page. Decided during implementation, after
the page transition went the wrong way for the previous song.

**Top bar** — 48 dp, hairline instead of a shadow. On a list: screen title (Newsreader 20) plus
add and settings. In a song: back, number in the accent, title with ellipsis, heart, and three-dot
menu in 40 × 48 dp targets.

**Bottom navigation** — Material 3 `NavigationBar`, three tabs, 48 dp height: 17 dp outline icon
and label on one line. Active: 2 dp bar in the accent, icon in the accent, label in the text
color, weight 600. Inactive: tertiary text.

**Dialog** — 12 dp radius, 24 dp padding. Title 19, body 15. Two actions **pushed apart to the
edges**: dismiss on the left, confirm on the right, each on its own color toned down
to 12% — **never as a filled button**. A destructive action uses the destructive color; „Anuluj” (Cancel)
uses secondary text and is no longer blue. A disabled action stays visible as a shape — neutral
background in the line color and tertiary text — so it does not look like a missing button.
Decided during implementation of step 5; replaces the earlier "two actions on the right".

**Sheet** — 34 × 3 dp drag handle, 52 dp items, destructive section separated by a hairline.

**Empty state** — 26 dp outline icon in the line color, Newsreader 21 heading, a 14/1.55 sentence
saying what to do, optionally one way out as a 48 dp pill button. Three occurrences:
no results, no favorites, no user songs. Never a large illustration.

**Post-migration welcome screen** — shown once to a user whose data was carried over by the migration
from the old iOS app (issue #37). Full screen without a bar, one way out: a pill button
„Zaczynajmy” (Let's begin) spanning the column width, min. 48 dp, at the bottom edge. Heading **Newsreader
300, 30 / 1.15** — the only size outside the interface scale, added during implementation because the
screen title (20) gets lost on an empty screen. The rest comes from the scale: body 15 / 1.5, subheading
„Co się zmieniło:” (What changed:) styled like a text button (15 / 1.2, Grotesk 600), list bullets in the accent. 24 dp margins, spacing
16 / 32 / 12 / 8 from section 4, column at most 34 × 19 dp, like song text at the default S. The content
scrolls when it does not fit under magnification. One-letter words („i”, „w”, „z”) are
bound to the following word with a non-breaking space so they do not stay at the end of a line.

**Slider** — 3 dp track, 20 dp thumb in a 48 dp target, 6 dp halo on touch. The value is always
written out as a number next to the name. Below the text size slider there is a song sample that updates
live.

---

## 6. Accessibility

- Touch areas: 16–17 dp icon in a target of **min. 40 × 48 dp**
- Tap feedback: the row background darkens for 80 ms and returns (instead of the globally
  disabled splash)
- Every action icon has `Semantics(label:)` **in Polish**
- Everything works at system font scaling ×1.3 and ×2.0

### Contrast measured during implementation (step 5d)

Calculated from the tokens, with semi-transparent colors composited over the background. Enforced by
`test/contrast_test.dart`, so changing a token fails the test instead of silently breaking contrast.

| Pair | Light | Dark | Threshold |
|---|---|---|---|
| primary text on background | 15.85:1 | 15.19:1 | 4.5 |
| secondary text on background | 6.43:1 | 6.88:1 | 4.5 |
| tertiary text on background | 4.90:1 | 5.40:1 | 3 |
| accent on background (search match, selected row) | 6.09:1 | 9.39:1 | 4.5 |
| text on accent (pill button) | 6.58:1 | 9.39:1 | 4.5 |
| destructive color on background | 6.80:1 | 7.60:1 | 4.5 |
| accent on its own 12% background | 4.74:1 | 6.09:1 | 4.5 |
| secondary text on its own 12% background | 5.00:1 | 4.67:1 | 4.5 |
| destructive color on its own 12% background | 5.13:1 | 5.13:1 | 4.5 |
| favorite heart on background | 7.26:1 | 7.88:1 | 3 |
| primary text in sheet and dialog | 14.51:1 | 12.71:1 | 4.5 |
| secondary text in sheet | 5.89:1 | 5.76:1 | 4.5 |
| text in search field | 17.12:1 | 13.73:1 | 4.5 |
| hint in search field | 5.30:1 | 4.88:1 | 3 |
| hairline on background | 1.24:1 | 1.34:1 | — |
| index dots on background | 1.61:1 | 1.92:1 | — |
| pressed row against background | 1.09:1 | 1.11:1 | — |
| **inactive arrow in the song bar** | 4.90:1 | 5.40:1 | 3 |
| **inactive navigation tab** | 4.90:1 | 5.40:1 | 3 |
| **disabled „Przejdź” (Go) button** (on line background) | 3.95:1 | 4.04:1 | 3 |

Lines, dots, and the pressed-row background have deliberately low contrast: they carry no content or state,
and their job is to stay out of the way. Everything that means something is above its threshold.

**Inactive states** went through two fixes during measurement: the arrow at the end of the hymnal used
the line color (1.24:1 — practically invisible), and the disabled „Przejdź” (Go) button took
Material's default `onSurface` at 38% (2.31:1 in the light theme). Both now use tertiary
text; that they are inactive is shown by the missing number next to the arrow and by the active actions
being in the accent or in secondary text.

---

## 7. Rules that must stay in the code

1. No fixed height on an element containing text — only `minHeight`.
2. Contrast is calculated against the background the element sits on, not against black.
3. Every action icon has `Semantics(label:)` in Polish.
4. Colors come only from `Theme.of(context)` — **zero literals in views and zero checks of
   theme brightness**.
5. Song text is scaled by S from the settings and additionally multiplied by the system `textScaler`,
   **never instead of it**.
6. The 2000-item list always uses `ListView.builder` with `itemExtent` **null** (the row grows
   with the font).

---

## 8. Icons

The Claude Design previews draw SVG strokes — in Flutter, their Material Icons equivalents are used
at 24 dp: `menu_book`, `favorite`, `favorite_border`, `edit_note`, `search`, `share`,
`more_vert`, `settings`.

---

## 9. Implementation order

| Step | Scope |
|---|---|
| 1 | **Tokens and theme** — two `ColorScheme`s, two typefaces, spacing scale, two radii, removal of color literals from views. This step alone eliminates the 1.5:1 bug. |
| 2 | **Row and lists** — one 48 dp row component for all three lists, persistent search field, sorting by number, tap feedback, empty states. |
| 3 | **Song renderer** — marker parser, drop cap, chorus uppercase label, repeat marks, 22 dp margin and column limit, scale derived from S. |
| 4 | **Navigation and dialogs** — song bar with previous song / number / next song, „Przejdź do pieśni" (Go to song) modal with the system keyboard, options sheet, dialogs from tokens. |
| 5 | **Accessibility** — screen reader labels, tap target audit, test at ×1.3 and ×2.0, contrast check of every pair in both themes. |

---

## 10. Decisions to make before implementation

Things the system changes beyond appearance alone — they require explicit sign-off:

1. **Migrating existing users' settings.** The line height range changes from 1.0–3.0
   to 1.4–1.8, the defaults from 16/1.5 to 19/1.62. Saved values outside the new range must be
   **clamped, not reset**; the new defaults apply only on first install.
2. **Swipe gesture between songs** — does it stay alongside the new bottom bar with arrows,
   or is it removed?
3. **The fast scrolling bar with a number label** goes away along with `itemExtent`. This removes
   `draggable_scrollbar` from issue #17 by dropping the feature, not by replacing it.
4. **New features in the options sheet**: „Kopiuj tekst" (Copy text), „Nie gaś ekranu" (Keep screen on),
   **„Zgłoś błąd w tekście"** (Report a text error) (a new feature — requires a decision on scope).
5. **Theme switch in settings** — today the app follows the system only.
6. **Three typefaces in the HTML file, two in the app.** IBM Plex Mono is used only for documentation.
   Newsreader and Schibsted Grotesk must be bundled as assets subset to latin + latin-ext,
   so as not to bloat the package.
