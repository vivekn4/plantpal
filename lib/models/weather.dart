/// A small snapshot of current weather. Only what the pet needs:
/// a kind, a temperature, whether it is day or night, and the wind
/// speed (30 km/h or more adds the wind effects layer).
enum WeatherKind { sunny, cloudy, rain, snow, unknown }

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.kind,
    required this.temperatureC,
    required this.isDay,
    required this.isFallbackLocation,
    this.windKmh = 0,
    this.fetchedAtUtc,
    this.stale = false,
  });

  final WeatherKind kind;
  final double temperatureC;
  final bool isDay;
  final bool isFallbackLocation;
  final double windKmh;
  final DateTime? fetchedAtUtc;
  final bool stale;

  String get label {
    switch (kind) {
      case WeatherKind.sunny:
        return 'Sunny';
      case WeatherKind.cloudy:
        return 'Cloudy';
      case WeatherKind.rain:
        return 'Rainy';
      case WeatherKind.snow:
        return 'Snowy';
      case WeatherKind.unknown:
        return 'Weather unavailable';
    }
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'temperatureC': temperatureC,
        'isDay': isDay,
        'isFallbackLocation': isFallbackLocation,
        'windKmh': windKmh,
        'fetchedAtUtc': fetchedAtUtc?.toIso8601String(),
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    final fetchedRaw = json['fetchedAtUtc'] as String?;
    final fetched = fetchedRaw == null
        ? null
        : DateTime.tryParse(fetchedRaw);
    // Cached weather older than 60 minutes is shown with a stale note.
    final stale = fetched == null ||
        DateTime.now().toUtc().difference(
              fetched.isUtc ? fetched : fetched.toUtc(),
            ) >
            const Duration(minutes: 60);
    return WeatherSnapshot(
      kind: WeatherKind.values.firstWhere(
        (kind) => kind.name == json['kind'],
        orElse: () => WeatherKind.unknown,
      ),
      temperatureC: (json['temperatureC'] as num?)?.toDouble() ?? 0,
      isDay: json['isDay'] as bool? ?? true,
      isFallbackLocation: json['isFallbackLocation'] as bool? ?? true,
      windKmh: (json['windKmh'] as num?)?.toDouble() ?? 0,
      fetchedAtUtc: fetched,
      stale: stale,
    );
  }
}

/// Maps an Open-Meteo WMO weather code to a pet weather kind.
WeatherKind weatherKindFromCode(int code) {
  if (code == 0 || code == 1) return WeatherKind.sunny;
  if (code == 2 || code == 3 || code == 45 || code == 48) {
    return WeatherKind.cloudy;
  }
  if (code >= 51 && code <= 67) return WeatherKind.rain;
  if (code >= 71 && code <= 77 || code == 85 || code == 86) {
    return WeatherKind.snow;
  }
  if (code >= 80 && code <= 82) return WeatherKind.rain;
  if (code == 95 || code == 96 || code == 99) return WeatherKind.rain;
  return WeatherKind.unknown;
}
