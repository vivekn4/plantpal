# PlantPal — Design System & Interface Spec

Designer deliverable for the build crew (PLAN.md §7, §9). This is the
single source of truth for how PlantPal looks, moves, and sounds. If
code and this document disagree, stop and fix this document first,
then the code — same rule as PLAN.md.

Status: design approved by the designer role. Still to come from other
roles: builder implementation, tester/QC pass, reviewer copy pass,
publisher release. Nothing here is shown to the user until the whole
crew green-lights.

---

## 1. The look in one paragraph

A 16-bit garden shelf, not a generic Material app. Warm cream
background, deep soil-brown ink, chunky 3 px borders, hard offset
shadows, flat colours, zero rounding, zero gradients, zero
glassmorphism. The pet is the biggest thing on every screen it
appears on. The water button is the brightest thing on every screen
it appears on — findable from across the room. Everything else gets
out of the way.

Human-made standard: copy is plain, warm, and short. No template
phrasing, no exclamation-mark spam, no gamification words (no XP,
levels, streaks, guilt trips), no mention of AI anywhere in the UI.

---

## 2. Palette (exact values — do not drift)

| Token | Hex | Used for |
| --- | --- | --- |
| `cream` | `#FFF6E3` | App background |
| `card` | `#FFFDF5` | Cards, sheets, speech bubbles |
| `sand` | `#FDE9B8` | Panels, badges, pressed-button fill |
| `ink` | `#3B2416` | Text, borders, outlines, eyes |
| `soil` | `#5B3A1E` | Secondary text, soil row (normal) |
| `soilDark` | `#3B2416` | Soil row for ~10 s after watering |
| `pot` | `#C96F3B` | Pot body |
| `potDark` | `#A8542A` | Pot shading |
| `leaf` | `#4C9A2A` | Foliage mid |
| `leafLight` | `#7BC950` | Foliage highlight |
| `leafPale` | `#A8E08A` | Foliage pale accent |
| `leafDark` | `#2E6B1E` | Foliage shadow |
| `leafMuted` | `#5F7D4F` | Thirsty foliage mid |
| `leafMutedLight` | `#7F966E` | Thirsty foliage highlight |
| `water` | `#2B7CD3` | Water button, droplets, links |
| `waterDark` | `#1D5FA8` | Water button border/pressed, water text on light bg |
| `waterLight` | `#8EC9F0` | Rain, splashes, droplet glints |
| `sun` | `#F5B301` | Sun, sparkles, stars |
| `sparkle` | `#FFE98A` | Star/sparkle pixels |
| `alert` | `#8A2B1D` | Overdue text/badges (on sand or cream, never white-on-alert alone) |
| `night` | `#1B2A4A` | Night overlay at ~45% opacity (never black, never full opacity) |
| `white` | `#FFFFFF` | Eye glints, text on waterDark/leafDark |

Contrast, measured (WCAG): ink on cream 13.5:1, ink on sand 12.1:1,
white on waterDark 6.5:1, white on leafDark 6.5:1, white on alert
8.6:1, ink on white 14.5:1. All body-text pairings pass AA; most
pass AAA. Never put body text in leaf, water, or sun on cream —
those are decoration and button fills only, with the dark variants
above carrying the text.

Night mode is NOT a theme: there is no dark theme in v1. Night only
dims the pet scene (night overlay + stars + Z pixels). All other
screens stay cream.

---

## 3. Type

- **Headings + pet speech:** Press Start 2P (Google Fonts, OFL).
  Headings 20 sp, pet speech 14 sp, never smaller — this font is
  wide, so keep lines short. Screen titles are one or two words
  ("My Plants", "Adopt", "Fern").
- **Body copy, buttons, badges:** Nunito (Google Fonts, OFL),
  Regular 600 for body, Bold 800 for buttons and badges. Body 16 sp,
  small text 14 sp, never below 14 sp for anything the user must
  read (due dates, button labels).
- **Numbers that matter** (days overdue, "Water on Thursday") are
  Nunito Bold, never pixel font — dates must stay readable.
- Builder note: Press Start 2P is already in the repo at
  `assets/fonts/PressStart2P-Regular.ttf` with its OFL licence
  (`assets/fonts/OFL.txt`) — use that file. Nunito is still to be
  fetched from Google Fonts (free, OFL) when wiring the theme;
  ship its licence file alongside it. Do not substitute a
  lookalike without a note in the design file.

---

## 4. Shape, spacing, and motion basics

- 8 px grid. Screen padding 16 px, card padding 16 px, gaps 12 px
  between cards, 8 px between a label and its control.
- Borders: 3 px solid ink on every card, button, bubble, and input.
  Corners: 0 px radius, everywhere. No exceptions for "just this
  one dialog".
- Hard shadow: 4 px right + 4 px down, solid ink at ~25% opacity
  (or solid `#3B2416` at low alpha — never a blur shadow).
- Button press: the whole button shifts 2 px down-right and the
  shadow drops to 0 px while pressed, then springs back on release.
  Every tappable thing visibly reacts — no silent taps.
- Idle motion is sparse by design: a bounce, a wiggle every few
  seconds, one sparkle at a time. Constant motion is tiring to look
  at and it steals attention from the state the pet is showing.

---

## 5. Components

### PixelButton

- Height 56 px (primary), 48 px (secondary). Full-width on phone
  for primary actions, never narrower than 160 px.
- **Primary (water):** water fill, white Nunito Bold 18 sp label,
  3 px waterDark border, hard shadow. Label always starts with the
  verb: "Water Fern", "I watered it". Icon: watering-can SVG,
  left of the label.
- **Secondary:** sand fill, ink text, 3 px ink border, hard shadow.
- **Danger (delete):** card fill, alert text, 3 px alert border.
  Delete always asks once ("Delete Fern? Its photo goes too.")
  and the confirm button reads "Delete it" — never a bare icon
  tap that destroys data.
- Disabled state: fill sand, text soil at 60%, no shadow, no press
  shift. Disabled buttons still show their label (never a spinner
  in place of the label).

### PetCard (home shelf)

- Card fill, 3 px ink border, hard shadow. Pet rendered at
  160 px wide (phone) centred at the top, speech line optional
  only for the most urgent pet (see §7).
- Under the pet: name (Press Start 2P, 16 sp, one line, truncates
  with …), species in Nunito 14 sp soil, then the DueBadge.
- Overdue cards get a 3 px alert top strip and the water button
  inline on the card ("Water it" compact, 48 px). Happy cards get
  no button — tapping the card opens the plant screen.
- Minimum touch target 48 x 48 px for every button and icon,
  even when the visible icon is 24 px.

### DueBadge

Text + colour + shape, never colour alone (accessibility, PLAN §7):

- Happy: "Happy" — leafDark text on leafPale chip, leaf icon.
- Due soon: "Due tomorrow" / "Due today" — ink text on sand chip,
  droplet icon.
- Overdue: "2 days overdue" — alert text on sand chip, droplet
  icon, plus the alert top strip on the card. The number is
  always whole days, always counted from the due date.
- Estimated (never watered, moisture-only first date): "First
  reminder estimated" — soil text on card fill, no chip fill.
  This wording is mandatory; never pretend the clock is real
  before the first "I watered it".

### SpeechBubble

Card fill, 3 px ink border, small square tail pointing down at the
pet, Press Start 2P 14 sp, ink text. One short line only (copy bank
in §8). The bubble never covers the pet's face. On the home shelf,
only the single most urgent pet (most overdue, else due-soon)
gets a bubble; the rest stay quiet or the shelf turns into noise.

### WeatherBadge

One row, 14 sp Nunito: weather icon (sun / wind / rain / snow /
moon SVG) + temperature + one plain word ("Sunny", "Rainy") +
location note. When location is off, the note reads exactly:
"Showing Sudbury weather — turn on location for yours". When the
fetch fails: "Weather unavailable" with the last-good weather
marked "stale" if one is cached. The badge never claims a city
it does not know. Weather never blocks the pet: the pet renders
first, the badge fills in when the fetch lands (10 s timeout).

### Inputs, toggles, steppers

- Text field: card fill, 3 px ink border, Nunito 16 sp, label
  above in Nunito Bold 14 sp. Hint text is soil, never a joke.
- Toggle: 56 x 32 px chunky switch, leaf fill when on, sand when
  off, 3 px ink border, square knob that slides (no animation
  beyond the slide — it is a switch, not a toy).
- Adopt stepper: "Step 1 of 3 — Photo" in Nunito Bold 14 sp soil,
  with three 12 px squares (filled = done, outline = to do).
  Back is always available and never loses entered data.

### VN signature

- Home header: "PlantPal" (Press Start 2P) with a small pixel
  sprout SVG, and a "VN" pixel mark (12 px squares spelling VN,
  ink on sand chip) at the right of the header. Tapping it opens
  About.
- About screen footer and Settings footer: "Built by VN" in
  Nunito Bold 14 sp, plus the one-line description: "Your plant,
  as a little pixel pet."
- The VN mark is a signature, not a logo treatment: keep it small,
  quiet, and in the same pixel language as everything else.

---

## 6. Screens

### Home — "My Plants" (pet shelf)

Layout (phone, 360–420 px wide): header (title + VN mark +
settings gear), weather badge row, then a 2-column grid of
PetCards. One urgent banner only if any pet is overdue: sand
panel, alert text, "2 plants need water" + a "Water them" button
that opens the first overdue plant (never a bulk-water action —
each plant's tap must save and verify on its own, PLAN bug #7).

Empty state: one code-drawn sample pet (trailing archetype,
happy face, from `design/pet_frames.json` — never a fake photo),
the line "No plants yet.", and one big primary button "Adopt
your first plant". No stock imagery, no illustration library.

Tablet / wide web (≥ 600 px): 3-column grid; ≥ 840 px: 4-column
grid, max content width 1024 px centred. Pet render scales to
192 px wide on tablet, 160 px on phone. The grid never stretches
cards — columns grow, cards keep their padding.

### Adopt — 3 steps, no more, back always works

- **Step 1 — Photo:** big square preview area (card fill, 3 px
  ink border, dashed inner guide square showing the centre-crop).
  Buttons: "Take a photo" (camera icon) and "Choose from gallery".
  Web fallback: file pick. Under the preview, one plain hint:
  "A brighter photo, with the plant filling the frame, makes a
  clearer pet." Blurry or dark photos still proceed — the hint
  is advice, never a rejection.
- **Step 2 — Name + species:** name field ("Name your plant",
  e.g. placeholder "Fern by the window" — a placeholder, not a
  suggestion the user must keep), species list as chunky radio
  rows (Pothos, Snake plant, Spider plant, Monstera, Peace lily,
  Succulent / cactus, Fern, Fiddle-leaf fig, Philodendron,
  ZZ plant, Other / I don't know). "Other" shows its note inline:
  "Waters about every 7 days. You can change this any time."
- **Step 3 — Watered? + soil?:** two question blocks, each a row
  of chunky toggle buttons. "Was it just watered?" Yes / No.
  "How does the soil feel?" Dry / Moist / Wet. A plain line under
  the soil question states the effect: "Dry waters sooner, wet
  waits longer." Then the primary button "Meet your pet".
- **Reveal:** the pet appears large with the celebration burst
  (droplets, jump, sparkles — §7), the speech line "Hi, I'm
  [name].", and one button "Take me home". If setup said
  just-watered = no, the plant screen shows the "first reminder
  estimated" wording (§5) instead of a fake clock.

### Plant screen — one pet, big

Pet rendered 280 px wide (phone) at the top, speech bubble above
it, weather badge below it. Under that, in order:

1. Next watering in plain words: "Water on Thursday" (Nunito
   Bold 20 sp) + "Every 7 days" underneath in 14 sp soil.
   Overdue instead reads: "2 days overdue — water today".
2. Primary water button "I watered it" (full width).
3. Interval editor: "Every [ 7 ] days" with − / + chunky buttons
   and a line that updates live: "That moves watering from
   Thursday to Sunday." Confirm is a secondary button "Save
   interval" — the date change is never silent (PLAN bug #9).
4. Watering history: a plain list of dates, newest first
   ("Watered Oct 24", "Watered Oct 17"). No charts in v1.
5. "Your photo" vs "Your pet" side-by-side pair (small, 120 px
   each) so the user sees what the pet was made from.
6. Danger zone at the bottom: "Delete plant" (danger button,
   confirm dialog as in §5).

Wide web (≥ 840 px): pet on the left, actions on the right, two
columns; the water button stays full-width of its column.

### Settings

Rows, each a chunky card: Location ("Use my location for
weather", toggle + the Sudbury fallback note when off), Sound
("Pet sounds", toggle — respected everywhere, including the
celebration), Reduced motion note ("PlantPal follows your
device's reduced-motion setting"), Weather source note
("Weather: Open-Meteo, free, no account"), About ("Built by VN",
licences: Press Start 2P + Nunito, OFL; SFX made for this app,
no attribution needed; species intervals are starting points,
not advice"). No account row, no sync row, no shop row — v1
has none of those, so the screen must not imply they exist.

---

## 7. Motion, particles, and sound

Full frame data lives in `design/pet_frames.json` (archetypes,
faces, animation states, particle specs). This section is the
contract for how those frames are used. Priority order, always:
**night (sleeping) > overdue/thirsty > weather > battery**.
A sleeping pet sleeps even if it is sunny; a thirsty pet looks
thirsty even on a full battery. Battery unknown = neutral energy,
never a faked level.

| Moment | Visual | Sound (file) | Notes |
| --- | --- | --- | --- |
| Any button tap | 2 px press shift + shadow drop | `click.wav` (880 Hz square, 60 ms) | Every tappable thing, no exceptions |
| Watering | 10 droplets fall, splash ripple, pet jumps, 6 sparkles, soil darkens ~10 s (all < 2 s) | `water_bloop.wav` (700→260 Hz sine sweep) + `sparkle.wav` on the jump | Plays ONLY after the save is verified (PLAN bug #7). If the save fails, no celebration — show the error plainly and keep the old state |
| Happy idle | Bounce loop, one leaf wiggle every few seconds, one sparkle every 5–9 s | None (no ambient sound, ever) | Sparse by design |
| Due soon | Slower bounce, pet glances toward the water button | None | |
| Thirsty | Droop + wilt sway, muted leaf colours | None | State also carried by text badge, always |
| Sunny | Face tilts up, relaxed sway, sun glints | None | |
| Windy | Foliage sways 1–2 cells, gusts bend the pet | `whoosh.wav` on tap only, never ambient | Gust strength maps to sway amplitude, capped at 2 cells |
| Rain | Pixel raindrops + leaf splashes, pet perks up | None | |
| Snow | Slow flakes, ±1 cell tremble, breath puffs | None | |
| Night | Dark-blue overlay (~45%), twinkling stars, floating Z pixels, breathing bob | `sleep_chime.wav` only when the plant screen is opened at night, never on a timer | Overrides every other state |
| Success (adopt reveal, interval saved) | Sparkle burst (6, 600 ms) | `success.wav` (523/659/784 Hz square arpeggio) | Short, then stop |
| Sound off | Nothing moves differently except: no audio at all | (silence) | The toggle silences everything, including celebrations |

SFX rules (PLAN §7, bug #11): all sounds trigger from a user tap
only — no autoplay, no ambient loops, no music loop in v1. Files
in `assets/sfx/` are original synthesized blips (square/triangle/
sine waves, no samples, no licence burden). Note: `bloop.wav`
sits alongside `water_bloop.wav` as an alternate — the canonical
watering sound is `water_bloop.wav`; wire one, not both.
The builder wires them through whatever small audio package it
justifies in pubspec; if a package cannot play a WAV from a tap
on web, the app still works silently — sound is never load-bearing.

Reduced motion: when the device requests it, cut every idle
animation to a gentle bob (no bounce, no sway, no particles
except the watering burst, which shortens to the jump only).
Effects never carry information alone: every state also has text
(§5 DueBadge) and is never colour-only.

---

## 8. Copy bank (plain, warm, human — use these lines, don't improvise)

- Pet speech, happy: "I'm doing well today."
- Pet speech, due soon: "Watering day is close."
- Pet speech, thirsty: "I'm thirsty."
- Pet speech, just watered: "Thanks. That hit the spot."
- Pet speech, night: "Zzz…" (in the bubble only when the plant
  screen is open at night; on the shelf, sleeping pets get no
  bubble — the dimmed scene says it).
- Pet speech, reveal: "Hi, I'm [name]."
- Empty shelf: "No plants yet."
- Weather unavailable: "Weather unavailable"
- Sudbury fallback: "Showing Sudbury weather — turn on location
  for yours"
- First reminder: "First reminder estimated — tap 'I watered it'
  to start the real clock"
- Delete confirm: "Delete [name]? Its photo goes too."
- Interval change preview: "That moves watering from [old] to
  [new]."
- Error, save failed: "That didn't save. Your plant is unchanged
  — try again." (Never blame the user, never show a stack trace.)

Banned in UI copy: XP, levels, streaks, "gamification" language,
guilt copy ("you neglected…", "shame on…"), exclamation-mark
runs, corporate app-speak ("leverage", "optimize your plant
journey"), any mention of AI.

---

## 9. Pet frames and the 120 px readability check

`design/pet_frames.json` defines three code-drawn archetypes
(trailing: pothos/philodendron/spider plant; upright: snake plant/
ZZ plant/fiddle-leaf fig; rosette: succulent/fern/peace lily/
monstera), ten face grids, the shared pot, per-archetype face
anchors, and every animation state with frame timings. Faces are
drawn in code over the avatar at render time, so mood changes
never require re-pixelating (PLAN §5). For real user photos, the
same face grids overlay the pixelated photo; if a face lands on
empty cells, the builder nudges the anchor ±1 row toward the
densest nearby row — never leave eyes floating on background.

Check performed by the designer (renders in `design/previews/`):

- Pothos, happy — full size: leafy head, eyes and smile sit on
  foliage, pot reads. PASS.
- Snake plant, thirsty, muted colours — at 120 px wide:
  silhouette and pot read, eyes read as two dark dots. The mouth
  is marginal at this size, which is acceptable only because the
  overdue text badge is mandatory (§5) — state is never carried
  by the face alone. PASS with that condition.
- Succulent, sleeping — at 120 px wide: rosette silhouette and
  pot read, closed-eye bars read. PASS.

One real defect was found and fixed during this check: the first
face anchor (6 rows above the pot) left the pothos face floating
in the hollow centre of the trailing archetype. Anchors are now
per-archetype (trailing row 2, upright row 9, rosette row 4) and
the renders above were re-checked after the fix. A second
defect was also fixed: two foliage grids were hand-counted at the
wrong width (25–26 cells, not 24). Widths are now per-archetype
in the JSON and validated by script, not by eye.

Design previews are reference renders for the builder, NOT
screenshots: the release screenshot must still be a real capture
of the built app in `assets/screenshot.png` (PLAN §9, reviewer
role). Never ship these previews as the app's screenshot.

---

## 10. Icons

`assets/icons/` holds 24 original SVG icons, drawn as chunky
pixel shapes (24 x 24 viewBox, hard edges, no emoji used as
icons anywhere): watering_can, droplet, sun, wind, rain, snow,
moon, sleep (Zzz), battery_full, battery_low, leaf, sprout,
plus, gear, camera, bell, trash, sound_on, sound_off, pin,
check, back, sparkle, history. Mapping: watering actions use
watering_can/droplet; weather badge uses sun/wind/rain/snow/moon;
settings uses gear; adopt uses camera/plus; delete uses trash;
sound toggle uses sound_on/sound_off; location uses pin.
Builder note: Flutter does not render SVG natively — either add
a small, well-maintained SVG package (justified in pubspec) or
redraw these shapes as CustomPainter paths. Do not swap in an
icon font's generic glyphs without noting the change here: the
pixel language is part of the design, not decoration.

---

## 11. Builder handoff checklist

- [ ] Theme tokens from §2/§3/§4 as a single theme file; no
      hard-coded hex outside it (except the pet painter, which
      reads `pet_frames.json` values).
- [ ] All four screens from §6, responsive at 360 / 600 / 840 px
      breakpoints, max content width 1024 px.
- [ ] Pet painter reads `design/pet_frames.json` archetypes and
      faces (move the data into `lib/` in whatever form fits;
      keep this JSON as the reviewed source until the move).
- [ ] Behaviour-matrix rows from PLAN §2 demonstrable, in the
      priority order of §7, with the reduced-motion path.
- [ ] Watering celebration gated on verified save; interval edit
      shows old → new date before confirming.
- [ ] Sound toggle respected everywhere; no autoplay; web build
      never crashes on a missing mobile API (battery/camera/
      notifications all have fallbacks).
- [ ] No gradients, no rounded glass, no emoji-as-icons, no AI
      mentions, no mockup screenshot, no keys or secrets.
- [ ] `flutter analyze` clean and `flutter build web` green
      before the design is called implemented (builder's gate,
      not claimed here — no Flutter toolchain exists on this
      machine, so the designer did not run those gates).

Out of scope for the builder to improvise: new screens, new pet
species art beyond the three archetypes, charts, accounts, sync,
or any change to the watering math — those need a plan/design
update first.

---

*— VN*
