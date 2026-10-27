# PlantPal icons — design reference

These 24 original SVGs are the design set documented in DESIGN.md.
They are reference art, not runtime assets: the Flutter app currently
renders its on-screen icons with Material Icons (see lib/), and
`flutter_svg` is deliberately not a dependency in v1, keeping the
dependency list short per PLAN.md.

Do not add these to `pubspec.yaml` assets until a future change
actually renders them — an unbundled file that looks like an app
asset is how a stale-icon mismatch happens. If a future version
switches to them, add `flutter_svg`, declare the folder, and update
this note in the same change.
