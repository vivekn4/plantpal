# PlantPal — Plan

> PlantPal turns a photo of your real plant into a little pixel pet that
> reminds you when it actually needs water. Built by VN.
> Stack: Flutter, one codebase, Android APK + HTML web app. Zero budget:
> no paid services, no API keys, no signups.

Date: 2026-10-26. Status: v1 built from this plan (fix round 1,
2026-10-26). This document is the spec the build crew works from.
If code and this plan disagree, stop and fix the plan first, then
the code.

---

## 1. Concept

### The one-sentence version

You take a photo of your plant, PlantPal turns it into a 16-bit pixel
pet, and the pet tells you — by how it looks and acts — when it needs
water, instead of you having to remember a schedule.

### How it works, end to end

1. **Adopt.** The user photographs their plant (camera, or pick from
   the gallery). The photo is pixelated down into a chunky 16-bit
   avatar: the plant's own shape and colours, just rendered as pixels.
   The original photo stays on the device and is never uploaded
   anywhere.
2. **Set up.** Two questions, nothing more:
   - Was it just watered? (yes / no)
   - How does the soil feel right now? (dry / moist / wet)
   - Plus a name for the plant, and a species pick from a short list
     (with an "I don't know / other" option that uses a safe default).
3. **Live.** The pet lives on the home screen. Its mood and animation
   always show its real state at a glance — no digging through menus:
   - Watered on time → happy, bouncy, bright.
   - Watering coming up → a gentle nudge, slightly droopy.
   - Overdue → thirsty and droopy, clearly asking for water.
   - Tapping "I watered it" resets the clock and the pet perks up.
4. **Remind.** When care is due, the pet notifies. On Android that is a
   local notification (scheduled on the device). On web, where true
   background notifications are unreliable, the due state is shown
   loudly in-app on open, plus an optional browser notification only
   while the page is open. No server, no account, no push service.

### What makes it PlantPal, not just another watering app

Most plant apps are a calendar with a photo attached. PlantPal flips
it: the plant itself is the interface. Battery, weather, and watering
state all show up as behaviour, so a quick glance at the pet tells you
everything — the same way glancing at a real plant tells you whether
it looks happy.

---

## 2. The pet's behaviour matrix (the heart of the app)

Animation is never random decoration. Every animation maps to one real
input. When two inputs compete, the priority order is:
**night (sleeping) > overdue/thirsty > due-soon/restless > weather >
battery**. A sleeping pet sleeps even if it is sunny; a thirsty pet
looks thirsty even on a full battery; a pet due soon looks restless
even in perfect weather. Wind is not a competing mood but a layer:
at 30 km/h or more it adds sway on top of the winning weather mood
(rain + wind still reads as rain, with flutter), and never over a
sleeping, thirsty, or restless pet.

| Input | Pet behaviour |
| --- | --- |
| Watered on time | Happy: bounce, bright eyes, occasional sparkle |
| Watering due soon (within 24h) | Restless: slower bounce, looks toward the water can |
| Watering overdue | Thirsty/droopy: leaves hang, slow wilt sway, dull colours |
| Just watered (tap "I watered it") | Celebration burst: droplets, jump, sparkles, then happy |
| Phone battery high (roughly 70%+) | Energetic: faster bounce, perkier idle motion |
| Phone battery low (roughly under 20%) | Sleepy/droopy: slow blink, heavy eyelids, slumped leaves |
| Weather: sunny | Basking: face tilts up, relaxed sway, sun glints |
| Weather: windy | Swaying with the wind, leaves fluttering, enjoying it |
| Weather: rain | Raindrops falling on the pet, leaves perk up a little |
| Weather: snow | Shivering: tiny tremble, huddled leaves |
| Night (local time, or weather API night flag) | Sleeping: closed eyes, slow breathing bob, "Z" pixels |
| Battery unknown (web without battery API) | Neutral energy — never fake a battery state |

Notes for the builder:

- Battery on the web is best-effort only (the browser Battery API is
  not available everywhere). If it is unavailable, the pet uses neutral
  energy and nothing breaks. Never show a made-up battery level.
- Weather comes from Open-Meteo (free, no key, no signup). If the
  network fails, the pet falls back to time-of-day only (day/night) and
  the weather badge reads "weather unavailable" — the watering logic
  never depends on weather.
- Location: device location only if the user grants it, otherwise
  default to Sudbury, Ontario. The default must be stated plainly in
  the UI ("Showing Sudbury weather — turn on location for yours"),
  never silently pretended to be the user's location.

---

## 3. Watering logic

All computed on-device from stored dates. No account, no sync, no
server clock — the device clock is the source of truth.

### Species database (built in, offline)

A small hand-written table shipped in the app, not fetched from
anywhere. Each entry: common name, default watering interval in days,
and a one-line care note. Starter set (expand only with entries the
crew can verify — no invented numbers):

- Pothos, snake plant, spider plant, monstera, peace lily, succulent /
  cactus (grouped, conservative interval), fern, fiddle-leaf fig,
  philodendron, ZZ plant, plus "Other / I don't know".

Rules:

- "Other" uses a conservative default interval (7 days) and says so.
- Intervals are starting points, not gospel. Every plant screen shows
  the interval and lets the user adjust it ("every __ days").
- The database file must be plain Dart/JSON in the repo so anyone can
  read and correct it. No scraped data, no copied database.

### Moisture adjustment (user's spec, exactly)

The setup answers shift the first due date from the species default:

- Soil **dry** → due sooner (default interval minus 2 days, minimum 1 day).
- Soil **moist** → due on the default interval.
- Soil **wet** → due later (default interval plus 2 days).

And "just watered = yes" at setup starts the clock at setup time;
"just watered = no" means the last-watered date is unknown, so the
first due date is computed from the moisture answer alone and the UI
says "first reminder estimated — tap 'I watered it' to start the real
clock" instead of pretending to know.

After setup, the rule is simple and stays simple:

- `nextDue = lastWatered + intervalDays`
- "Due soon" = within 24 hours of `nextDue`.
- "Overdue" = past `nextDue`, counted in whole days ("2 days overdue").

Edge cases the builder must handle, not hand-wave:

- User waters early → clock resets from the new date, pet celebrates.
  No penalty, no guilt copy.
- User changes the interval → next due date recomputes from the last
  watered date, immediately, and the UI shows the new date. For a
  plant never watered yet, the estimated first due date shifts by
  the same number of days (so the moisture shift in the estimate is
  kept), and confirming the edit saves that shifted date — the
  preview must never promise a move the saved plant does not make.
- Clock jumps / timezone changes → store dates in UTC, display in
  local time. A date stored as local text will break across travel;
  UTC storage avoids it.
- Multiple plants → each plant has its own clock, its own pet, its
  own notification. The home screen is a shelf of pets, not one pet
  with a list buried behind it.

---

## 4. Architecture

One Flutter codebase, two outputs. Keep it boring and small — this is
a pet app, not a platform.

```
lib/
  main.dart                 App entry, theme, routing
  models/
    plant.dart              Plant: id, name, species, avatar path,
                            lastWateredUtc, intervalDays, createdUtc
    species.dart            Offline species table + defaults
    weather.dart            Weather snapshot model (code, temp, isDay)
  services/
    plant_store.dart        Local persistence (see below)
    watering.dart           Pure date math: next due, status, moisture shift
    weather_service.dart    Open-Meteo fetch + Sudbury fallback
    battery_service.dart    Battery level, with "unknown" as a real state
    notification_service.dart Local notifications (Android); web no-op guard
    pixelate.dart           Photo -> 16-bit avatar (see section 5)
  widgets/
    pixel_pet.dart          The animated pet (CustomPainter, frame-based)
    pixel_button.dart       Chunky pixel buttons
    weather_badge.dart      Small weather + location note
  screens/
    home_screen.dart        Shelf of pets, due badges
    adopt_screen.dart       Photo + setup questions
    plant_screen.dart       One pet big, care actions, history
    settings_screen.dart    Location toggle, sound toggle, interval edit
assets/
  fonts/                    Pixel font (open licence only, licence file kept)
  sfx/                      Short original blips (see section 7)
  screenshots/              Real captures only (see section 8)
```

### Persistence

- Plants, watering history, and settings live in local on-device
  storage only (shared_preferences for settings + a local JSON/SQLite
  store for plants — builder picks one and documents why; do not add
  both).
- Photos: the original photo and the pixelated avatar are stored in
  the app's private documents directory. They are never sent to any
  server, analytics, or cloud service — because there is none.
- Deleting a plant deletes its photo and avatar too. No orphan files
  left behind, no "recently deleted" cloud copy.

### Platform notes

- **Android:** full feature set — camera, gallery, local notifications,
  battery level.
- **Web:** same app, honest limits — camera becomes file pick where
  unavailable, battery is best-effort, background notifications are
  not promised. The web build must never crash on a missing mobile
  API; every platform service has a web fallback path.
- **No iOS target in v1.** Do not add iOS config half-done; Android +
  web only, stated in the README.

### Dependencies — keep the list short

Only well-maintained, free, openly licensed packages, each justified
in pubspec comments: image picking, local storage, local
notifications, battery, HTTP (for Open-Meteo), and a pixel font. No
analytics, no crash reporting, no ads SDK, no auth package — there is
nothing to authenticate against. Every new dependency needs a reason
in the PR/plan note, or it does not go in.

### Builds (read this before touching a terminal)

- **Local APK builds are BLOCKED on this machine** — the sandbox
  blocks the TCP connections Gradle needs, so `flutter build apk`
  will fail here no matter what. Do not burn time retrying it, and do
  not try to work around the sandbox.
- **APK is built on GitHub Actions:** `.github/workflows/build-apk.yml`
  runs `flutter build apk --release` on a runner and uploads the APK
  as a workflow artifact (and to a GitHub Release when tagged).
- **Web is built on GitHub Actions:** `.github/workflows/pages.yml`
  runs `flutter build web --release` and deploys to GitHub Pages.
- **Local gates that DO run here:** `flutter analyze` must be clean,
  and `flutter build web` must succeed. Those two are the pre-merge
  bar for every change. If analyze is not clean, the change is not
  done.
- No secrets in either workflow. Open-Meteo needs no key; there is
  nothing to put in repository secrets. If a future step ever asks
  for a key, stop — that step does not belong in this app.

---

## 5. The pixel avatar: photo → 16-bit pet

Original code only. No ripped game sprites, no stock pixel art, no
generated images. The avatar is derived from the user's own photo, so
every pet is unique by construction.

Pipeline (all on-device):

1. Take or pick the photo. Downscale to a small grid first (target
   roughly 48×48 cells for the pet body area, tuned by the builder for
   readability at phone size).
2. Quantize colours: snap each cell to a small fixed palette (greens,
   earth tones, pot colours, plus the photo's dominant hues clamped
   into that palette). Chunky pixels, hard edges, no smoothing, no
   anti-aliasing — smoothing kills the 16-bit look.
3. Optional cleanup pass: fill single-pixel noise, keep the silhouette
   readable at 120px wide (the thumbnail test — if the pet is a blob
   at 120px, the grid is too fine).
4. Store the pixelated result as the avatar. Keep the original photo
   alongside it for the plant detail screen ("your photo" vs "your pet").
5. Eyes and expression are drawn in code on top of the avatar at
   render time (happy eyes, sleepy eyes, droopy lids), not baked into
   the image — so mood changes never require re-pixelating.

Failure modes to design for:

- Blurry or dark photo → still pixelate, but show a plain hint ("try
  a brighter photo with the plant filling the frame") instead of
  failing or showing a broken image.
- Photo of something that is not a plant → the app does not judge;
  it pixelates whatever was photographed. No plant-detection model,
  no ML dependency, no false rejection.
- Very wide / tall photos → centre-crop to square before pixelating,
  with the crop preview shown so the user sees what the pet is made
  from.

---

## 6. Likely bugs + mitigations

| # | Likely bug | Why it happens | Mitigation (build it in, not after) |
| --- | --- | --- | --- |
| 1 | Notifications never fire on Android | Battery optimisation kills scheduled alarms; exact-alarm permission denied | Request exact-alarm / ignore-optimisation where allowed, explain why in plain words, and always show the due state in-app as the backup — notification is a bonus, the home screen is the truth |
| 2 | Due date wrong after travel / clock change | Dates stored as local text | Store UTC, display local; unit-test a timezone jump |
| 3 | Web build crashes on battery/camera APIs | Mobile-only plugins throw on web | Every platform service has a web fallback returning "unknown"; test `flutter build web` on every change |
| 4 | Pixel avatar looks like mud | Grid too fine, palette too wide, smoothing left on | Fixed small grid, clamped palette, no smoothing, 120px readability check in review |
| 5 | Weather shows the wrong city | Location denied but UI still claims local weather | Sudbury fallback is labelled as Sudbury, always; never present fallback weather as local |
| 6 | Weather fetch blocks the pet | Network call on the UI thread / no timeout | 10s timeout, cached last-good weather shown with a "stale" note, pet renders before weather arrives |
| 7 | Overdue pet never recovers | "I watered it" tap fails to persist | Write-then-verify: persist, re-read, then animate the celebration only on confirmed save |
| 8 | Photo lost on app update / reinstall | Stored in cache dir, which the OS may clear | Store in documents dir, never cache/temp; note in README that reinstall without backup loses pets (no cloud) |
| 9 | Interval edit silently moves a due date backwards | Recompute from last-watered without telling the user | Show old → new due date on the edit screen before confirming |
| 10 | Gradle/APK workflow rots | Nobody runs it until release day | Every push runs analyze + web build; APK workflow runs on tags and weekly, so breakage is found early |
| 11 | Sound annoys / sounds broken on web | Autoplay policies block audio before user gesture | All SFX trigger from a tap only; sound toggle defaults on for taps, off for ambient loops; no autoplay |
| 12 | analyse warnings creep in | Lints ignored to ship faster | `flutter analyze` clean is a merge gate, no exceptions, no `// ignore` without a comment saying why |

General rule: every bug above gets a regression check the reviewer can
run in under a minute (a test, a build command, or a screen to look
at). "Fixed, trust me" is not a fix.

---

## 7. UI/UX thinking

### Look and feel — 16-bit throughout

- Pixel font for headings and pet speech; a clean readable font for
  body copy (pixel fonts at paragraph size are unreadable — do not
  force it).
- Chunky borders, hard shadows, flat colours, no gradients, no rounded
  glassmorphism. If a screen could pass for a generic Material app,
  it is not done yet.
- Palette: deep soil brown + leaf greens + warm cream background,
  with one bright accent (water blue) reserved for watering actions.
  The water button should be findable from across the room.
- Pet speech: short, plain lines in a pixel speech bubble ("I'm
  thirsty!", "Thanks! That hit the spot.", "Zzz…"). No cutesy
  paragraph monologues, no slang that dates the app, no jokes about
  the user. The pet talks about the plant, not about itself as a
  program.

### Screens

- **Home (pet shelf):** grid of pets, each with name, due badge
  ("due tomorrow", "2 days overdue", "happy"), and a one-tap water
  button on overdue pets. Empty state: one big "Adopt your first
  plant" button and a sample pet drawn in code (never a fake photo).
- **Adopt flow (3 setup steps + pet reveal):** photo → name + species →
  watered? + soil? → pet reveal with celebration. Each step fits on
  one phone screen without scrolling where possible. Back is always
  available; nothing is lost going back a step.
- **Plant screen:** pet large, speech bubble, next-watering date in
  plain words ("Water on Thursday"), interval editor, watering
  history (dates only, no charts in v1), delete plant.
- **Settings:** location on/off, sound on/off, weather source note
  ("Weather: Open-Meteo, free, no account"), about + licence notes.

### SFX + VFX (maximalist, but with an off switch)

This account's style is maximalist effects — PlantPal leans into it,
kept tasteful because the pet is the star:

- **Watering:** droplet particles falling, splash ripple, a rising
  "bloop" blip, pet jump + sparkles, soil darkens a shade. The best
  moment in the app — make it feel good.
- **Happy idle:** occasional sparkle twinkle, gentle bounce, leaf
  wiggle every few seconds (not constant — constant motion is
  tiring to look at).
- **Wind:** leaves flutter with a soft whoosh; stronger gusts bend
  the whole pet slightly.
- **Rain:** pixel raindrops, tiny splashes on leaves, pet perks up.
- **Snow:** slow falling flakes, pet tremble, breath puff pixels.
- **Night:** dim the scene (dark blue overlay, not black), stars
  twinkle, "Z" pixels float up, pet breathing bob.
- **Buttons:** chunky press-down animation (2px shift + shadow drop)
  and a short click blip. Every tappable thing must visibly react.
- **Sounds:** short original blips made in code or from a tiny
  royalty-free set with licence kept in the repo. No recorded voice,
  no music loop in v1 (a loop gets annoying fast; revisit only if
  users ask). Sound toggle on settings and respected everywhere —
  including the celebration.
- **Accessibility, non-negotiable:** effects never carry information
  alone — every state also has text ("2 days overdue") and colour is
  never the only signal. Reduced-motion: honour the system setting
  by cutting idle animation to a gentle bob; SFX off must silence
  everything.

### Copy tone

Plain, warm, human. Short sentences. No corporate app-speak, no
exclamation-mark spam, no "gamification" language (no XP, levels,
streaks, or guilt trips in v1 — the pet asks, it does not punish).
If a line sounds like it came from a template, rewrite it.

---

## 8. Scope limits (v1 — what is NOT being built)

Saying no here is what keeps v1 shippable:

- **No accounts, no login, no cloud sync, no backend.** Everything
  on-device. Multi-device sync is out of scope until a real user asks.
- **No plant identification by photo.** No ML model, no paid
  identification API. The user picks the species; "I don't know" is
  a first-class answer.
- **No plant shop, no ads, no in-app purchases, no subscriptions.**
- **No social features, no sharing feed.** (Sharing a screenshot of
  your pet via the OS share sheet is fine if trivial; it is not a
  feature to build around.)
- **No iOS build in v1.** Android APK + web only.
- **No automatic watering hardware, no sensor integration.** Soil
  moisture is what the user feels and taps, not a probe reading.
- **No reminders by email or SMS.** Local notifications + in-app
  due state only.
- **No charts, graphs, or "plant health scores" in v1.** Dates and
  plain words beat a fake precision score.
- **No AI images, no ripped sprites, no copied art.** All pixel art
  is code-drawn from the user's photo or drawn as original shapes.
  Sample/demo pets are code-drawn too.

Anything beyond this list needs a plan update and a reason, not a
quiet scope creep in a pull request.

---

## 9. Per-role deliverables

The crew works in this order. Nothing is shown to the user until every
role below gives its green light — unanimous sign-off is mandatory.

| Role | Owns | Done means |
| --- | --- | --- |
| Producer (this plan) | PLAN.md, scope, behaviour matrix, watering rules | This document, reviewed against the user's spec line by line |
| Designer | Pixel style guide, pet animation frames/states, screen layouts, palette + font picks (open licence) | A style sheet + frame list the builder can implement without guessing; 120px readability check passed on sample pets |
| Builder | Flutter app: models, services, screens, pixelate pipeline, weather + battery + notifications, CI workflows | `flutter analyze` clean, `flutter build web` succeeds, APK + Pages workflows present and valid YAML; every behaviour-matrix row demonstrable |
| Tester / QC | Unit tests (watering math, moisture shift, UTC handling), widget tests (adopt flow, water tap), manual pass on Android + web | Test list mapped to section 6 bugs; a written pass/fail per row, no silent skips |
| Reviewer (human-made + portfolio) | Copy read-through, README, screenshot, repo description | Copy has no template/AI feel; README has a Screenshot section with a real capture in `assets/screenshot.png` (never a mockup); one-line repo description set; VN signature/tag present |
| Publisher | GitHub repo (vivekn4/plantpal), Actions runs green, GitHub Pages live, Release APK attached on tag | Live Pages URL + APK artifact link verified by opening them, not by reading a green checkmark |

### Release checklist (all must be true before v1 is called done)

- [ ] `flutter analyze` clean
- [ ] `flutter build web` succeeds locally
- [ ] APK workflow + Pages workflow run green on GitHub Actions
- [ ] Adopt → water → overdue → water-again loop works on Android
        and web without a crash on any missing platform API
- [ ] Every behaviour-matrix row (section 2) seen working, not just
      coded
- [ ] Photos stay on-device (no network call carries a photo — verify
      by inspection: the only network call is Open-Meteo weather)
- [ ] README with Screenshot section, real `assets/screenshot.png`,
      one-line description, VN tag
- [ ] No keys, secrets, or paid-service references anywhere in the repo
- [ ] Unanimous crew green light, recorded before anything is shown
      to the user

---

## 10. Repo layout (target)

```
plantpal/
  PLAN.md
  README.md
  pubspec.yaml
  analysis_options.yaml
  lib/                  (see section 4)
  test/                 (unit + widget tests)
  assets/
    fonts/              (+ licence)
    sfx/                (+ licence/attribution if any)
    screenshot.png      (real capture, added at release — never a mockup)
  .github/workflows/
    build-apk.yml       (Android APK on GitHub Actions runners)
    pages.yml           (Flutter web -> GitHub Pages)
```

---

*— VN*
