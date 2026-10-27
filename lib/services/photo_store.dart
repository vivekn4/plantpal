/// Photo storage, platform-split by conditional import.
///
/// Mobile stores files in the app's private documents directory (never
/// cache/temp, so an OS cleanup cannot eat a pet — PLAN.md bug 8).
/// Web has no documents directory, so it stores the same bytes as
/// base64 in local preferences. Either way, photos never leave the
/// device: the only network call in the app is Open-Meteo weather.
library;

export 'photo_store_io.dart'
    if (dart.library.js_interop) 'photo_store_web.dart';
