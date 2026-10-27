/// A plant and everything the app needs to care for it.
/// All dates are stored in UTC and converted to local time for display,
/// so travel and clock changes cannot shift a due date (PLAN.md bug 2).
class Plant {
  Plant({
    required this.id,
    required this.name,
    required this.speciesId,
    required this.intervalDays,
    required this.createdUtc,
    this.lastWateredUtc,
    this.firstDueUtc,
    List<DateTime>? wateredHistoryUtc,
    this.hasPhoto = false,
    this.hasAvatar = false,
  }) : wateredHistoryUtc = wateredHistoryUtc ?? const [];

  final String id;
  final String name;
  final String speciesId;
  final int intervalDays;
  final DateTime createdUtc;
  final DateTime? lastWateredUtc;

  /// First due date when the last-watered date is unknown (setup with
  /// "just watered = no"). Once the plant is watered for real, the
  /// normal lastWatered + interval rule takes over.
  final DateTime? firstDueUtc;
  final List<DateTime> wateredHistoryUtc;

  /// Whether an original photo / pixel avatar is stored for this plant.
  final bool hasPhoto;
  final bool hasAvatar;

  Plant copyWith({
    String? name,
    String? speciesId,
    int? intervalDays,
    DateTime? lastWateredUtc,
    DateTime? firstDueUtc,
    List<DateTime>? wateredHistoryUtc,
    bool? hasPhoto,
    bool? hasAvatar,
  }) {
    return Plant(
      id: id,
      name: name ?? this.name,
      speciesId: speciesId ?? this.speciesId,
      intervalDays: intervalDays ?? this.intervalDays,
      createdUtc: createdUtc,
      lastWateredUtc: lastWateredUtc ?? this.lastWateredUtc,
      firstDueUtc: firstDueUtc ?? this.firstDueUtc,
      wateredHistoryUtc: wateredHistoryUtc ?? this.wateredHistoryUtc,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      hasAvatar: hasAvatar ?? this.hasAvatar,
    );
  }

  /// Same as [copyWith] but able to clear [lastWateredUtc] explicitly.
  Plant withLastWatered(DateTime? value, List<DateTime> history) {
    return Plant(
      id: id,
      name: name,
      speciesId: speciesId,
      intervalDays: intervalDays,
      createdUtc: createdUtc,
      lastWateredUtc: value,
      firstDueUtc: firstDueUtc,
      wateredHistoryUtc: history,
      hasPhoto: hasPhoto,
      hasAvatar: hasAvatar,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'speciesId': speciesId,
        'intervalDays': intervalDays,
        'createdUtc': createdUtc.toIso8601String(),
        'lastWateredUtc': lastWateredUtc?.toIso8601String(),
        'firstDueUtc': firstDueUtc?.toIso8601String(),
        'wateredHistoryUtc': wateredHistoryUtc.map((d) => d.toIso8601String()).toList(),
        'hasPhoto': hasPhoto,
        'hasAvatar': hasAvatar,
      };

  factory Plant.fromJson(Map<String, dynamic> json) {
    DateTime parse(String? value, DateTime fallback) {
      if (value == null) return fallback;
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return fallback;
      return parsed.isUtc ? parsed : parsed.toUtc();
    }

    final created = parse(json['createdUtc'] as String?, DateTime.now().toUtc());
    return Plant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Plant',
      speciesId: json['speciesId'] as String? ?? 'other',
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 7,
      createdUtc: created,
      lastWateredUtc: json['lastWateredUtc'] == null
          ? null
          : parse(json['lastWateredUtc'] as String?, created),
      firstDueUtc: json['firstDueUtc'] == null
          ? null
          : parse(json['firstDueUtc'] as String?, created),
      wateredHistoryUtc: ((json['wateredHistoryUtc'] as List<dynamic>?) ?? [])
          .map((e) => parse(e as String?, created))
          .toList(),
      hasPhoto: json['hasPhoto'] as bool? ?? false,
      hasAvatar: json['hasAvatar'] as bool? ?? false,
    );
  }
}
