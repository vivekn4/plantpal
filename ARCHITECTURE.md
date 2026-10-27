# PlantPal — Architecture

> Companion to `PLAN.md`. The plan states what PlantPal does; this document
> states how it is built, so the builder never has to guess. If code and
> this document disagree, stop and fix this document first, then the code.
> If this document and `PLAN.md` disagree, `PLAN.md` wins and this document
> gets corrected.
>
> Stack: Flutter, one codebase, Android APK + HTML web app. Zero budget:
> no paid services, no API keys, no signups, no analytics, no ads, no
> auth. Everything on-device except one free, keyless weather fetch.

Date: 2026-10-26. Status: architecture only — no app code yet.

---

## 1. Design principles (the rules behind every decision below)

1. **Boring over clever.** One store, one state mechanism, one weather
   source, no platform-specific UI branches beyond the fallbacks in
   section 8. A pet app is not a platform.
2. **Pure core, thin shell.** All date math, moisture rules, pet-state
   resolution, weather-code mapping, and colour quantisation are pure
   Dart functions with no Flutter, network, or clock dependency. The
   shell (screens, services, painters) only calls them. This is what
   makes the app testable without a device.
3. **Unknown is a real state, never a fake value.** Battery unknown,
   weather unavailable, last-watered unknown, location denied — each
   has an explicit representation and an honest UI label. Nothing is
   ever invented to fill a gap.
4. **The home screen is the truth.** Notifications are a bonus. Every
   state the app promises must be visible in-app even if notifications,
   weather, or battery all fail.
5. **Photos never leave the device.** The only network call in the app
   is the Open-Meteo weather fetch, which carries coordinates only —
   never a photo, name, or plant data. Verify by inspection (see
   section 10).
6. **No scope creep by import.** Every dependency below is justified;
   anything not listed here does not go in `pubspec.yaml` without a
   note in this document saying why.

---

## 2. Tech stack (free only)

| Layer | Choice | Why / licence note |
| --- | --- | --- |
| Language / UI | Flutter (stable) + Dart, Material widgets restyled to 16-bit (see `lib/theme/`) | One codebase for Android + web; no iOS target in v1, so no iOS config is touched |
| State | No state-management package. `PlantStore` and `SettingsStore` extend `ChangeNotifier`; screens rebuild with `ListenableBuilder` | Zero new concepts, zero version risk; the app has one shelf of plants, not a state graph |
| Persistence (data) | `shared_preferences` only — plants as one versioned JSON document (section 5) | One plugin, works on Android and web, no native DB, no migration framework for v1 |
| Persistence (photos) | `path_provider` on mobile only; web stores bytes via `shared_preferences` (section 5) | Mobile photos live in the documents dir (never cache/temp); web has no documents dir, so it uses the same key-value store the data already uses |
| Photo picking | `image_picker` | Camera + gallery on Android; file pick on web where camera is unavailable |
| Pixelation | `image` package for decode/encode only; grid sampling, quantise, denoise hand-written (section 7, decision 10 as amended) | `dart:ui` cannot JPEG-encode, and web originals need downscaling; the grid/quantise logic is still the product, with nearest-neighbour sampling stated explicitly |
| Weather | `http` to Open-Meteo only | Free, no key, no signup; one GET, 10 s timeout, cached (section 6) |
| Location (optional) | `geolocator` | Only used when the user turns location on; denied/unavailable → Sudbury fallback, labelled as such |
| Battery | `battery_plus` | Level on Android; `unknown` on web or on any error — never a guessed number |
| Notifications | `flutter_local_notifications` + `timezone` (Android only; web no-op) | Local scheduling only; `timezone` is required for correct zoned scheduling across travel |
| Sound effects | `audioplayers`, tap-triggered only | Short original blips; no autoplay, no music loop in v1 |
| Fonts | Press Start 2P (SIL OFL) for headings + pet speech only; system sans for body copy | Pixel font at paragraph size is unreadable — body copy never uses it; licence file kept in `assets/fonts/` |
| Linting | `flutter_lints` (already in `pubspec.yaml`) | `flutter analyze` clean is a merge gate, no exceptions |
| CI | GitHub Actions (section 9) | Local APK builds are blocked on the dev box (Gradle TCP sandbox); runners build the APK |

Explicitly **not** used in v1: `sqflite` / any SQL store (one store only),
any state-management package, `intl` (dates are formatted by the small
hand-rolled formatter in `watering.dart` — weekday/month names are a
fixed list, and that is all v1 needs), any image-processing package,
any ML/plant-ID package, any analytics/crash/ads/auth package,
`cupertino_icons` (remove it — the app ships no iOS-styled icons).

---

## 3. Module structure

Final layout. File names are exact; the builder creates these files and
no others without updating this document.

```
plantpal/
  PLAN.md
  ARCHITECTURE.md            (this file)
  README.md
  pubspec.yaml               (dependencies in section 2 only, each commented)
  analysis_options.yaml
  lib/
    main.dart                App entry: creates stores/services, wires
                             fallbacks, runs PlantPalApp. No logic here.
    theme/
      app_theme.dart         Colours, pixel borders, hard shadows, text
                             styles (pixel headings, readable body).
                             The single source of the palette.
    models/
      plant.dart             Plant entity + JSON (de)serialisation.
      species.dart           Offline species table + defaults (section 4).
      weather.dart           WeatherSnapshot model (code, temp, isDay,
                             wind, fetchedAtUtc, isStale).
      pet_state.dart         WateringStatus, BatteryState, PetWeather,
                             PetPose, PetState — all enums/records, no logic.
    services/
      clock.dart             Clock abstraction: SystemClock (real) and
                             FakeClock (tests). All date math takes a
                             "now" — nothing calls DateTime.now() directly
                             outside clock.dart.
      watering.dart          Pure date math: next due, status, moisture
                             shift, plain-words dates (section 4).
      pet_state_resolver.dart Pure priority resolution (section 6).
                             Input: watering + battery + weather + night.
                             Output: PetState. No widgets, no services.
      plant_store.dart       ChangeNotifier. Owns the plant list, all
                             mutations (adopt, water, edit interval,
                             delete), write-then-verify, notification
                             rescheduling hooks. The only writer of
                             plant data.
      settings_store.dart    ChangeNotifier. Location on/off, sound
                             on/off, reduced-motion follows the system
                             (not a stored setting — see section 8).
      photo_store.dart       PhotoStore interface + MobilePhotoStore
                             (documents dir) + WebPhotoStore (base64 in
                             shared_preferences). Deletes with the plant.
      pixelate.dart          Pure pipeline: crop, grid-sample, quantise,
                             denoise, PNG encode (section 7).
      weather_service.dart   Open-Meteo fetch, Sudbury fallback, cache,
                             stale flag, 10 s timeout (section 6).
      battery_service.dart   Battery level → BatteryState (section 6).
      notification_service.dart Android scheduling/cancel; web no-op
                             that always reports "not scheduled"
                             (section 6).
      sfx_service.dart       Tap-triggered blips only; honours the sound
                             toggle and the system mute path (section 8).
    widgets/
      pixel_pet.dart         Pet widget: drives one AnimationController
                             ticker, hands time + PetState to the painter.
      pixel_pet_painter.dart CustomPainter: draws the 48×48 avatar grid
                             (FilterQuality.none), code-drawn eyes/
                             expression, weather FX, particles. Eyes are
                             NEVER baked into the avatar image.
      pixel_button.dart      Chunky button: 2 px press shift + shadow
                             drop + click blip. Every tappable thing
                             uses it or an equivalent visibly-reacting
                             control.
      pixel_speech_bubble.dart Short pet lines only, pixel font.
      due_badge.dart         Text badge ("due tomorrow", "2 days
                             overdue", "happy") — text always present,
                             colour never the only signal.
      weather_badge.dart     Weather + location note ("Showing Sudbury
                             weather — turn on location for yours" when
                             on fallback).
    screens/
      home_screen.dart       Pet shelf grid, per-pet due badge, one-tap
                             water button on overdue pets, empty state
                             with a code-drawn sample pet (never a photo).
      adopt_screen.dart      3-step flow: photo → name + species →
                             watered? + soil? → reveal. Back always
                             available; nothing is lost going back.
      plant_screen.dart      One pet large, speech bubble, next-watering
                             date in plain words, interval editor with
                             old → new preview, watering history (dates
                             only), delete plant.
      settings_screen.dart   Location toggle, sound toggle, weather
                             source note, about + licence notes.
  test/
    watering_test.dart       Section 10, group A.
    pet_state_resolver_test.dart  Section 10, group A.
    pixelate_test.dart       Section 10, group A (quantise + denoise).
    weather_mapping_test.dart Section 10, group A (WMO → PetWeather).
    species_test.dart        Section 10, group A.
    plant_store_test.dart    Section 10, group B (in-memory fakes).
    adopt_flow_test.dart     Section 10, group B (widget test).
    water_tap_test.dart      Section 10, group B (widget test).
    interval_edit_test.dart  Section 10, group B (widget test).
  assets/
    fonts/                   (+ OFL licence file)
    sfx/                     (+ licence/attribution file if any asset
                             is not made in code)
    screenshot.png           Real capture only, added at release.
  .github/workflows/
    build-apk.yml            APK on tags + weekly (section 9).
    pages.yml                Web build → GitHub Pages on push to main.
```

---

## 4. Data model and watering logic

### 4.1 Plant (the only entity)

```dart
class Plant {
  final String id;              // uuid-style random string, created at adopt
  final String name;            // user-typed, trimmed, non-empty (adopt validates)
  final String speciesId;       // key into the species table, or 'other'
  final String originalPhotoRef; // opaque ref from PhotoStore (path on mobile, key on web)
  final String avatarRef;       // opaque ref from PhotoStore (48×48 PNG)
  final int intervalDays;       // user-editable, clamped 1..60
  final DateTime? lastWateredUtc; // null = unknown (setup answered "no")
  final DateTime createdUtc;    // adopt time, UTC
  final DateTime firstDueUtc;   // frozen at adopt (see 4.3); superseded
                                // by lastWateredUtc + intervalDays once the
                                // user waters for real after setup
  final int firstDueShiftDays;  // -2, 0, or +2 from the setup soil answer
  final bool hasRealWatering;   // true once "I watered it" is tapped post-setup
  final List<DateTime> wateredHistoryUtc; // every confirmed watering, UTC, newest last
}
```

Rules: all `DateTime`s are stored as UTC ISO-8601 strings in JSON and
displayed in local time only at the screen layer. No local-time text is
ever stored. `id` is never reused; deleting a plant deletes its photos
via `PhotoStore.delete` in the same mutation (section 5).

### 4.2 Species table (`species.dart`)

```dart
class Species {
  final String id;            // e.g. 'pothos', 'other'
  final String commonName;    // e.g. 'Pothos'
  final int defaultIntervalDays;
  final String careNote;      // one line, plain words
}
```

Starter set (from `PLAN.md`): pothos, snake plant, spider plant,
monstera, peace lily, succulent/cactus (grouped), fern, fiddle-leaf
fig, philodendron, ZZ plant, plus `other`. Fixed rule: `other` =
7 days, labelled "safe default — adjust it to your plant". For every
other species, the interval is a user-adjustable starting point, and
the builder fills it only from a value the reviewer can verify; any
species whose interval cannot be verified ships at the same
conservative 7 days with its care note saying so. No invented numbers
are presented as facts, and every plant screen shows the interval with
an editor — the table is a starting point, never gospel.

### 4.3 Watering math (`watering.dart` — pure functions, all take `now`)

```dart
// Moisture shift, applied ONCE at adopt time (PLAN §3, exactly):
//   dry -> -2 days (floor: resulting first due is at least 1 day out)
//   moist -> 0 days
//   wet -> +2 days
int moistureShiftDays(SoilMoisture soil); // dry: -2, moist: 0, wet: +2

DateTime computeFirstDueUtc({
  required DateTime baseUtc,       // lastWateredUtc ?? createdUtc
  required int intervalDays,
  required int shiftDays,          // from moistureShiftDays
}); // = baseUtc + max(1, intervalDays + shiftDays) days when base is
   // createdUtc (unknown case); baseUtc + (intervalDays + shiftDays)
   // days when base is a real watering. Never before baseUtc + 1 day.

// The live due date:
DateTime nextDueUtc(Plant plant);
//   if plant.hasRealWatering: plant.lastWateredUtc! + intervalDays
//   else: plant.firstDueUtc (frozen at adopt)

WateringStatus statusOf({required DateTime nextDueUtc, required DateTime now});
//   overdue  : now > nextDueUtc            -> "N days overdue" (whole days)
//   dueSoon  : nextDueUtc - now <= 24h     -> "due tomorrow" / "due today"
//   happy    : otherwise
//   estimated: plant.lastWateredUtc == null -> same bands as above, but
//              the label is prefixed "estimated — " and the plant screen
//              adds "tap 'I watered it' to start the real clock"

String plainWordsDate(DateTime utc, DateTime now); // "Water on Thursday",
  // "Water today", "Water tomorrow" — weekday names from a fixed list.
String overdueLabel(DateTime nextDueUtc, DateTime now); // "2 days overdue"
```

Mutation rules (all through `PlantStore`, write-then-verify — section 5):

- **Water tap:** set `lastWateredUtc = now (UTC)`, `hasRealWatering =
  true`, append to history, persist, re-read, and only then play the
  celebration. If persist-or-reread fails, show an error and play no
  celebration. No penalty copy, no guilt copy.
- **Interval edit:** recompute immediately and show old → new before
  confirming. If `hasRealWatering`, new due = `lastWateredUtc +
  newInterval`. If not, new `firstDueUtc = base + newInterval +
  firstDueShiftDays` (same floor as adopt). The edit screen displays
  both dates; confirm writes, cancel writes nothing.
- **Early watering:** identical to a normal water tap — the clock
  resets from the new date, full stop.
- **Clock jumps / travel:** impossible to corrupt by construction —
  UTC storage plus local display. Covered by a timezone-jump unit
  test (section 10).

### 4.4 Key interfaces (data layer)

```dart
abstract class PlantStore extends ChangeNotifier {
  List<Plant> get plants;                       // sorted: overdue first,
                                                // then due soon, then happy
  Future<Plant> adopt(AdoptInput input);        // validates, pixelates via
                                                // Pixelate, stores photos,
                                                // computes firstDueUtc, persists
  Future<void> waterPlant(String id, DateTime nowUtc); // write-then-verify
  Future<void> updateInterval(String id, int days, DateTime nowUtc);
  Future<void> deletePlant(String id);          // deletes photos too
  Future<void> reload();                        // re-read from storage (verify step)
}

class AdoptInput {
  final String name;
  final String speciesId;
  final Uint8List photoBytes;   // original, as picked
  final bool justWatered;       // setup answer
  final SoilMoisture soil;      // dry / moist / wet
}

abstract class PhotoStore {
  Future<String> saveOriginal(String plantId, Uint8List bytes);
  Future<String> saveAvatar(String plantId, Uint8List pngBytes);
  Future<Uint8List?> read(String ref);
  Future<void> deleteForPlant(String plantId);  // removes both files/keys
}
```

`PlantStore` never touches the filesystem or `shared_preferences`
directly in a way tests cannot replace: it takes a `PlantStorage`
abstraction (JSON document read/write) plus a `PhotoStore` plus a
`NotificationService`, all constructor-injected. Production wires the
real ones in `main.dart`; tests wire in-memory fakes.

---

## 5. Persistence (one store, decided)

**Decision: `shared_preferences` is the only data store. No SQLite.**
Rationale: v1 has one shelf of plants (tens, not thousands), one JSON
document is trivially inspectable and debuggable, and adding a SQL
plugin would add native build risk on both targets for no v1 benefit.
If a future version outgrows it, that version writes a migration, not
this one.

- **Key:** `plantpal.plants.v1` → JSON array of `Plant` objects.
  The `.v1` suffix is the migration hook: a future format uses `.v2`
  and converts on first read.
- **Settings keys:** `plantpal.settings.location` (bool),
  `plantpal.settings.sound` (bool, default on for taps, off for
  ambient loops — there are no ambient loops in v1, so this is
  effectively the tap-sound toggle).
- **Photos — mobile:** `path_provider` `getApplicationDocumentsDirectory()`
  → `plants/<plantId>/original.jpg` and `plants/<plantId>/avatar.png`.
  Never the cache or temp dir (the OS may clear those — PLAN bug 8).
- **Photos — web:** original downscaled to max 1024 px on its long edge
  before storing (keeps `localStorage` sane), then base64 under
  `plantpal.photo.<plantId>.original` / `.avatar`. Same `PhotoStore`
  interface, chosen by `kIsWeb` in `main.dart`.
- **Delete semantics:** `deletePlant` removes the plant from the JSON
  document AND calls `PhotoStore.deleteForPlant`. A test asserts no
  orphan photo survives a delete (section 10).
- **Reinstall honesty:** no cloud exists, so reinstall without a backup
  loses pets. The README and the settings screen say this plainly.
- **Corrupt document:** if the JSON fails to parse, the app starts with
  an empty shelf plus a plain-words notice ("Your saved plants
  couldn't be read — starting fresh") rather than crashing. The
  corrupt document is left untouched on disk for inspection.

---

## 6. Behaviour resolution and platform services

### 6.1 Pet state resolution (`pet_state_resolver.dart` — pure)

Priority order, from `PLAN.md` §2, applied as **layers** so competing
inputs combine instead of clobbering each other:

```dart
enum WateringStatus { happy, dueSoon, overdue, estimated }
// (estimated is a label modifier on happy/dueSoon/overdue, not a pose)
enum BatteryState { high, normal, low, unknown } // high >= 70, low < 20
enum PetWeather { sunny, cloudy, windy, rainy, snowy, unknown }
enum PetPose { happy, restless, thirsty, sleeping, celebrating }

class PetState {
  final PetPose pose;        // the body/face — ONE winner, by priority
  final double energy;       // bounce speed multiplier: 1.3 high, 1.0
                             // normal/unknown, 0.55 low
  final PetWeather weatherFx; // rain/snow/wind/sun overlay, or none
  final bool dimmed;         // night scene dimming
  final String speechLine;   // short line for the bubble (or '' for none)
}

PetState resolvePetState({
  required WateringStatus watering,
  required bool isNight,
  required BatteryState battery,
  required PetWeather weather,
  required bool celebrating,   // transient ~3 s post-water UI state, not stored
});
```

Priority, decided exactly (later stages never override earlier ones):

1. **Celebrating** (transient, tap-driven) beats everything for ~3 s,
   then the state recomputes. It is UI-held, never persisted.
2. **Night** beats everything else for the pose: pose = `sleeping`,
   `dimmed = true`, speech suppressed (no bubble, or "Zzz…" pixels
   only). The due badge text still shows overdue/due-soon — night
   hides the pose, never the information.
3. **Overdue** beats weather and battery for the pose: pose =
   `thirsty`. Weather FX still render (rain falls on a thirsty pet),
   but rain does NOT perk the leaves up while overdue — the perk-up
   applies only when watering is happy/due-soon.
4. **Due-soon** → pose `restless` (looks toward the water can).
5. **Happy** → pose `happy`.
6. **Weather FX layer** (independent of pose, except the overdue
   perk-up rule above): snowy → flakes + tremble; rainy → drops +
   splashes; windy → flutter + lean; sunny → basking tilt + glints;
   cloudy/unknown → no FX.
7. **Battery energy layer** (independent of pose, except night):
   high → faster bounce; low → slow blink, heavy eyelids, slumped
   leaves (energy 0.55, eyelid overlay on); unknown → neutral 1.0,
   and the UI never shows a battery number.
8. **Speech line** is picked from the winning pose first ("I'm
   thirsty!", "Thanks! That hit the spot.", "Zzz…"), never from
   weather or battery alone. Lines are short, plain, and about the
   plant — no slang, no monologues, no jokes about the user.

Worked combinations (the reviewer checks these, not just the code):
night + overdue → sleeping pose, dimmed, overdue badge text visible;
overdue + rain → thirsty pose + raindrops, no perk-up; low battery +
sunny + happy → happy pose, slow bounce, basking tilt; web + no
battery API → energy 1.0, no battery UI anywhere.

### 6.2 Weather (`weather_service.dart`)

- **Source:** Open-Meteo forecast API, one GET, no key:
  `latitude`, `longitude`, `current=temperature_2m,weather_code,is_day,wind_speed_10m`,
  `timezone=auto`, `forecast_days=1`. Timeout 10 s, on a background
  isolate-free async call that never blocks pet rendering — the pet
  renders immediately with `PetWeather.unknown`, weather fills in
  when it arrives.
- **Location:** if the settings location toggle is on AND permission
  is granted, device coordinates; otherwise Sudbury, Ontario
  (46.49, -80.99). The badge always states which one is in use.
- **WMO code mapping** (pure function, unit-tested):
  0, 1 → sunny; 2, 3, 45, 48 → cloudy (no FX); 51, 53, 55, 61, 63, 65,
  66, 67, 80, 81, 82, 95, 96, 99 → rainy; 71, 73, 75, 77, 85, 86 → snowy.
  Windy is a separate flag, not a code: `wind_speed_10m >= 30 km/h`
  adds the wind FX layer on top of the code's FX (rain + wind =
  drops + flutter).
- **Night:** `is_day == 0` from the API when available; fallback when
  weather is unavailable: local hour >= 21 or < 6.
- **Cache:** last-good snapshot + `fetchedAtUtc` kept in memory and in
  `shared_preferences` (`plantpal.weather.lastgood`). Older than
  60 min → shown with a "stale" note. Fetch failure → keep last-good
  (or unknown) and badge reads "weather unavailable". Watering logic
  never reads weather.
- **Privacy:** the request carries coordinates only. Nothing else.

### 6.3 Battery (`battery_service.dart`)

```dart
Future<BatteryState> currentBatteryState();
//   Android: battery_plus level -> high >= 70, low < 20, else normal.
//   Web / any error / plugin missing: unknown. No exception escapes.
```

### 6.4 Notifications (`notification_service.dart`)

```dart
abstract class NotificationService {
  Future<bool> get canSchedule;         // Android: permission state
  Future<void> scheduleDueReminder(Plant plant); // 09:00 local on due date
  Future<void> cancelForPlant(String plantId);
  Future<void> rescheduleAll(List<Plant> plants);
}
```

- Android: one notification per plant, scheduled for **09:00 local on
  the due date** (a friendly hour, not midnight), channel
  `plantpal_due`, title = pet name, body = plain words ("Time to
  water <name>"). Exact-alarm / ignore-battery-optimisation permission
  is requested once with a plain-words explanation; if denied, the
  app still works — the home screen is the truth (PLAN bug 1).
- Reschedule triggers: adopt, water tap, interval edit, delete
  (cancel), app start (reconcile — scheduled reminders are cheap to
  rewrite and this heals missed updates).
- Web implementation: no-op returning `canSchedule = false`. The web
  due state is shown loudly in-app on open, plus an optional browser
  notification only while the page is open (v1: in-app banner only;
  the browser-notification permission prompt is NOT added in v1 —
  it is a post-v1 decision, not a quiet addition).
- Notification IDs: stable per plant — `plant.id.hashCode` masked to
  a positive 31-bit int — so rescheduling replaces rather than
  duplicates.

---

## 7. Pixel avatar pipeline (`pixelate.dart` — pure, on-device)

Input: picked photo bytes. Output: 48×48 grid + PNG bytes. Steps,
in order, no step skippable:

1. **Decode** with the `image` package (decision 10 as amended), no
   smoothing anywhere in the pipeline.
2. **Centre-crop to square** (the crop preview on the adopt screen
   shows exactly this square, so the user sees what the pet is made
   from).
3. **Grid-sample to 48×48** with nearest-neighbour sampling (each
   cell takes its source block's sample — no smoothing, no averaging
   blur). 48 is fixed — finer grids turn to mud at phone size,
   coarser grids lose the plant's shape (PLAN bug 4).
4. **Quantise** to a fixed 16-colour palette by nearest RGB distance
   (pure function, unit-tested). Palette (greens, earth, pot, cream —
   the only colours an avatar may contain):
   deep leaf `#2E7D32`, leaf `#43A047`, light leaf `#66BB6A`, sprout
   `#AED581`, soil `#5D4037`, dark soil `#3E2723`, pot terracotta
   `#BF360C`, pot clay `#D84315`, cream `#FFF8E1`, stem `#33691E`,
   water blue `#0288D1`, sun yellow `#FDD835`, night blue `#1A237E`,
   stone grey `#78909C`, white `#FFFFFF`, black `#212121`.
   No smoothing, no anti-aliasing, hard edges only.
5. **Denoise, one pass:** a cell whose four orthogonal neighbours all
   share one colour (and differ from it) takes that colour. This
   removes single-pixel noise without blurring the silhouette.
6. **Encode PNG** at 48×48 (the painter upscales with
   `FilterQuality.none` at display size).
7. **Store** avatar PNG + original (downscaled on web only, section 5).

Failure behaviour (decided, not hand-waved): blurry/dark photos still
pixelate, with a plain hint ("Try a brighter photo with the plant
filling the frame"). A photo of something that is not a plant is
pixelated without judgement — no detection model exists in v1.
Non-square photos are centre-cropped, never stretched.

**Readability gate:** every sample pet must read as a plant at
120 px wide. If it is a blob at 120 px, the grid/palette is wrong,
not the photo. The reviewer runs this check by eye (section 10).

**Eyes/expression are render-time only** (`pixel_pet_painter.dart`):
happy eyes, sleepy lids, droopy lids, "Z" pixels, sparkles, and
droplets are drawn over the grid each frame. Mood changes never
re-pixelate, and the stored avatar never contains a face.

---

## 8. UI, effects, and accessibility (architecture decisions)

- **Theme (`app_theme.dart`):** deep soil brown + leaf greens + warm
  cream background + water blue reserved for watering actions. Chunky
  borders, hard shadows, flat colours, no gradients, no rounded
  glassmorphism. If a screen could pass for a generic Material app,
  it is not done.
- **Animation driver:** one `AnimationController` per pet widget
  (looping ticker), with all motion computed from elapsed time
  (`sin`/`cos` phases) — no sprite sheets, no frame assets. Particle
  seeds derive from `plant.id` so a pet's sparkles are stable, not
  re-randomised every rebuild.
- **Effects inventory (maximalist, with an off switch):** watering =
  droplet particles + splash ripple + rising "bloop" + jump +
  sparkles + soil darkens one shade; happy idle = occasional sparkle
  + gentle bounce + leaf wiggle every few seconds (never constant);
  wind = flutter + lean; rain = drops + splashes; snow = flakes +
  tremble + breath puffs; night = dark-blue overlay (not black) +
  twinkling stars + floating "Z" pixels; buttons = 2 px press + blip.
  Every effect lives in the painter or `sfx_service.dart`, never
  inline in screens.
- **Sound rules:** all SFX fire from a tap handler only (browser
  autoplay policy — PLAN bug 11). The sound toggle defaults on for
  tap sounds; there are no ambient loops in v1, so there is nothing
  ambient to toggle off. The toggle silences everything, including
  the watering celebration. No recorded voice, no music loop in v1.
- **Accessibility, non-negotiable:**
  - Effects never carry information alone — every state also has
    text (`due_badge.dart`) and colour is never the only signal.
  - Reduced motion: honour `MediaQuery.disableAnimations` — idle
    animation collapses to a gentle bob, particles stop, pose and
    text stay. This follows the system setting; it is not a stored
    app setting.
  - Touch targets: every button ≥ 48×48 dp; the water button on
    overdue pets is the largest control on the home card.
  - Text contrast: body copy on cream meets normal contrast; badge
    text never relies on a light colour on a light ground.
- **Copy:** plain, warm, human, short sentences. Pet lines are about
  the plant. No XP/levels/streaks/guilt language, no exclamation-mark
  spam, no template phrasing. The reviewer reads every string aloud
  before greenlight (see the human-made standard in `PLAN.md` §9).

---

## 9. Data flow (the four flows the builder implements)

### 9.1 Adopt

```
pick photo -> centre-crop preview -> name + species -> watered? + soil?
  -> PlantStore.adopt:
       pixelate (48×48 PNG) -> PhotoStore.save both
       -> compute firstDueUtc (4.3) -> persist JSON -> re-read (verify)
       -> schedule notification (09:00 on due date)
       -> reveal screen + celebration
```
Back at any step keeps already-entered answers. A failure at any step
shows a plain-words error and loses nothing already entered.

### 9.2 Home render (every frame, cheap)

```
PlantStore (ChangeNotifier)
  -> home_screen builds one PixelPet per plant
  -> weather_service snapshot (cached, may be unknown)
  -> battery_service state (cached per minute, may be unknown)
  -> resolvePetState(...) [pure] -> PetState
  -> pixel_pet_painter draws grid + eyes + FX
```
Weather and battery are fetched on a timer (weather: on open + every
30 min while open; battery: on open + every 60 s), never per frame,
never on the UI thread without a timeout.

### 9.3 Water tap (write-then-verify — PLAN bug 7)

```
tap "I watered it" -> PlantStore.waterPlant:
  persist new lastWateredUtc + history
  -> re-read from storage -> compare
  -> on match: cancel + reschedule notification, THEN celebration
  -> on mismatch: error message, no celebration, state unchanged
```

### 9.4 Weather refresh (never blocks the pet)

```
open app / 30 min timer -> weather_service.refresh (10 s timeout)
  -> success: update snapshot, cache last-good
  -> failure: keep last-good (stale note if > 60 min) or unknown
  -> pet already rendered with whatever was available
```

---

## 10. Testing strategy (mapped to PLAN §6 — every bug gets a check)

### Group A — pure unit tests (fast, no device, run on every change)

| Test file | Covers | PLAN bug |
| --- | --- | --- |
| `watering_test.dart` | next-due math; dry −2 / moist 0 / wet +2; min-1-day floor; due-soon 24 h boundary; overdue whole days; interval-edit recompute (both branches); early-water reset; UTC storage + timezone-jump display (construct two clocks, same instant, different zones) | 2, 9 |
| `pet_state_resolver_test.dart` | Full priority table: night > overdue > due-soon > happy; celebrating beats all; overdue + rain = thirsty + drops, no perk-up; night + overdue = sleeping + badge; low battery = energy 0.55, unknown = 1.0, no battery number anywhere | (matrix §2) |
| `pixelate_test.dart` | Quantise maps known colours to the nearest palette entry; denoise fixes an isolated pixel and leaves real edges alone; grid is exactly 48×48 | 4 |
| `weather_mapping_test.dart` | Every WMO code in §6.2 maps to the right PetWeather; wind flag at ≥ 30 km/h; unknown code → cloudy/unknown, never a crash | 5, 6 |
| `species_test.dart` | Every starter species present; `other` = 7 days; every interval in 1..60; every care note non-empty, one line | (§4.2) |

### Group B — store + widget tests (in-memory fakes, no device)

| Test file | Covers | PLAN bug |
| --- | --- | --- |
| `plant_store_test.dart` | Adopt → water → overdue → water-again loop; write-then-verify failure shows error, no celebration; delete removes plant AND photos (fake PhotoStore asserts zero orphans); corrupt JSON → empty shelf + notice, no crash | 7, 8 |
| `adopt_flow_test.dart` | 3 steps in order, back preserves answers, empty name blocked with a plain message, reveal shows the pet | — |
| `water_tap_test.dart` | Overdue card's water button triggers celebration only after confirmed save; happy card has no overdue badge | 7 |
| `interval_edit_test.dart` | Edit screen shows old → new date before confirm; cancel writes nothing; confirm recomputes immediately | 9 |

### Group C — manual / build gates (reviewer runs, under a minute each)

| Check | Command / screen | PLAN bug |
| --- | --- | --- |
| Analyze clean | `flutter analyze` — zero issues, no unexplained `// ignore` | 12 |
| Web build | `flutter build web` succeeds on every change | 3 |
| Web missing-API pass | Web build opened with battery/location denied: pet renders, battery neutral, weather badge honest | 3, 5 |
| Android due loop | Adopt → water → overdue → water-again on a device/emulator, notification scheduled at 09:00 on due date | 1 |
| 120 px readability | Sample pets viewed at 120 px wide; silhouette reads as a plant | 4 |
| Photo privacy inspection | `grep` the codebase for network calls: only the Open-Meteo GET exists; no photo bytes near any `http` call | (§1.5) |
| Sound + motion | Sound toggle off = silence everywhere; system reduced-motion on = bob only, no particles | 11 |
| Screenshot | Real capture → `assets/screenshot.png`, never a mockup | (release) |

**No golden (pixel-diff) tests in v1** — the painter is time-based and
goldens would be brittle; the 120 px eye check is the gate instead.

### CI (GitHub Actions — the APK constraint, decided)

- **On every push/PR:** `flutter analyze` + `flutter build web` +
  `flutter test`. A red run blocks merge. This is the pre-merge bar.
- **`pages.yml`:** on push to main, build web and deploy to GitHub
  Pages. No secrets in the workflow.
- **`build-apk.yml`:** on version tags AND weekly (schedule trigger),
  `flutter build apk --release` on the runner, APK uploaded as a
  workflow artifact and attached to the GitHub Release on tags. The
  weekly run exists so workflow rot is found early, not on release
  day (PLAN bug 10). No secrets in the workflow — Open-Meteo needs
  no key, and any future step asking for a key stops the build.
- **Local gates that do run here:** `flutter analyze` and
  `flutter build web`. `flutter build apk` is never run locally on
  the dev box — the sandbox blocks Gradle's TCP connections, and
  retrying it or working around the sandbox is forbidden by
  `PLAN.md` §4.

---

## 11. Decisions log (where PLAN was ambiguous, what was decided)

These are the only judgement calls the builder needs. If the reviewer
overturns one, it changes here first, then in code.

1. **One store, decided:** `shared_preferences` JSON only; no SQLite.
   "Do not add both" in `PLAN.md` is read as "do not add both JSON
   and SQLite".
2. **No state package:** `ChangeNotifier` + `ListenableBuilder` only.
   The app is too small for a framework.
3. **Moisture shift is one-time:** it sets `firstDueUtc` at adopt and
   never applies again. After the first real watering, dues are
   plain `lastWatered + interval`.
4. **Unverified species intervals fall back to 7 days** with an honest
   care note, rather than shipping invented numbers as facts.
5. **Notification time is 09:00 local on the due date**, not the exact
   due instant (which is usually midnight and useless).
6. **Web notifications in v1 are in-app only.** No browser-permission
   prompt is added; that is a post-v1 decision.
7. **Wind threshold is 30 km/h** (`wind_speed_10m`), as an FX layer
   on top of the WMO-code weather, not a separate weather type.
8. **Night fallback is local hour ≥ 21 or < 6** when the API gives no
   `is_day`.
9. **Web originals are downscaled to 1024 px** before base64 storage,
   so `localStorage` stays sane; mobile keeps full originals.
10. **No `intl`, no golden tests** — each is replaced above by a
    smaller, named mechanism. The `image` package IS used, amended
    2026-10-26 by the builder: `dart:ui` can decode but cannot
    JPEG-encode, and web originals need downscaling before base64
    storage; `image` is pure Dart (no native risk, works on web) and
    is used for decode/encode only. Grid sampling, palette quantise,
    and denoise remain hand-written in `pixelate.dart`, with
    nearest-neighbour interpolation stated explicitly, so the
    smoothing risk the original decision feared is still addressed.
11. **Celebration is transient UI state (~3 s), never persisted.**
    A restart mid-celebration simply shows the happy pose.
12. **Reduced motion follows the system setting** (`MediaQuery.
    disableAnimations`), not a second app toggle.
13. **Single state holder, not two stores (builder, 2026-10-26).**
    `AppState` (a `ChangeNotifier`) owns the plant list, settings,
    weather, and battery, with `PlantStore` as the plain JSON
    persistence layer underneath. Same property as the two-store
    design (one writer, `ListenableBuilder` rebuilds) with one less
    indirection; the pure functions still take `now` as a parameter,
    and UI call sites use `DateTime.now().toUtc()` only at the
    boundary instead of a `clock.dart` abstraction.
14. **File layout, close but not literal (builder, 2026-10-26;
    wind layer amended by fix round 1, 2026-10-26).**
    Theme lives at `lib/theme/app_theme.dart`; the mood enum and
    resolver live together in `pet_state_resolver.dart` (no separate
    `pet_state.dart`); `photo_store.dart` picks its implementation
    by conditional import rather than an interface + classes;
    `pixel_pet.dart` holds the widget and its painters in one file;
    the text badge is `due_badge.dart` and the bubble is
    `speech_bubble.dart`. No `settings_store.dart`: settings ride in
    `AppState` via `PlantStore`. Behaviour is a single resolved mood
    plus a wind flag, not the layered pose + energy + FX record:
    the priority order is night > overdue > due-soon > weather >
    battery, and wind at 30 km/h or more adds a sway layer on top
    of the winning weather mood (rain + wind still reads as rain,
    with flutter) via `windSwayApplies`, never over sleeping,
    thirsty, or restless; the due badge text always carries the
    information even when night hides the pose.
15. **`firstDueUtc` is nullable, and there is no `firstDueShiftDays`
    or `hasRealWatering` field (builder, 2026-10-26).** PLAN.md wins
    on the moisture rule: a plant set up as "just watered" starts
    its clock at setup with no shift, so it has no first due date
    to freeze; a plant set up as "not watered" freezes the shifted
    estimate in `firstDueUtc`. `lastWateredUtc != null` is exactly
    the "has a real watering" condition, so a separate boolean
    would be a second source of truth. The shift itself is not
    stored because it is already baked into `firstDueUtc`.
16. **Settings live in one JSON document** (`settings_v1`), not
    separate `plantpal.settings.*` keys — same store, same
    reasoning as section 5, one less key to keep in sync.
17. **Photo file layout (builder, 2026-10-26).**
    `plantpal/<plantId>_photo.jpg` and `<plantId>_avatar.png`
    directly under the documents dir, not `plants/<plantId>/`
    subdirectories — same guarantee (documents dir, deleted with
    the plant), flatter paths.

---

## 12. What the builder must not do

- Add a dependency not listed in section 2 without updating this
  document with a reason.
- Store a date as local text, call `DateTime.now()` outside
  `clock.dart`, or present fallback weather as local weather.
- Bake eyes into the avatar, smooth or anti-alias the grid, or use
  any sprite, stock pixel art, or generated image.
- Add iOS config, accounts, sync, analytics, ads, plant ID, charts,
  health scores, or any other v1 scope exclusion from `PLAN.md` §8.
- Run `flutter build apk` locally on the dev box, or add a secret to
  either workflow.
- Show anything to the user before the full crew greenlight
  (`PLAN.md` §9): Designer, Builder, Tester/QC, Reviewer, Publisher —
  unanimous, recorded.

---

*— VN*
