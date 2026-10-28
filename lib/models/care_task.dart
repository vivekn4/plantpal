/// A care task that is not watering: fertilize, mist, rotate, prune,
/// repot. This is the pattern every other plant app uses — Planta,
/// Leaflet, Plantoto and the open-source WaterMe all keep watering
/// separate from the other rhythms, instead of folding everything
/// into one interval — so PlantPal now does the same, on-device.
///
/// A task is deliberately simple: a kind, an interval in days, and
/// the next due date. Marking it done moves the next due date to
/// done + interval. There is no server, no account, and no
/// "health score" — the date in plain words is the whole feature.
enum CareTaskKind { fertilize, mist, rotate, prune, repot }

extension CareTaskKindLabel on CareTaskKind {
  String get label => switch (this) {
        CareTaskKind.fertilize => 'Fertilize',
        CareTaskKind.mist => 'Mist',
        CareTaskKind.rotate => 'Rotate',
        CareTaskKind.prune => 'Prune',
        CareTaskKind.repot => 'Repot',
      };

  /// Conservative starting interval, in days. The user can change
  /// it per task; like the species intervals, this is a starting
  /// point, not botanic law.
  int get defaultIntervalDays => switch (this) {
        CareTaskKind.fertilize => 30,
        CareTaskKind.mist => 7,
        CareTaskKind.rotate => 14,
        CareTaskKind.prune => 90,
        CareTaskKind.repot => 365,
      };
}

CareTaskKind? careTaskKindFromId(String id) {
  for (final kind in CareTaskKind.values) {
    if (kind.name == id) return kind;
  }
  return null;
}

class CareTask {
  const CareTask({
    required this.kind,
    required this.intervalDays,
    required this.nextDueUtc,
  });

  final CareTaskKind kind;
  final int intervalDays;
  final DateTime nextDueUtc;

  CareTask copyWith({int? intervalDays, DateTime? nextDueUtc}) {
    return CareTask(
      kind: kind,
      intervalDays: intervalDays ?? this.intervalDays,
      nextDueUtc: nextDueUtc ?? this.nextDueUtc,
    );
  }

  /// Marking a task done: the next due date is done + interval.
  CareTask doneAt(DateTime doneUtc) {
    return copyWith(nextDueUtc: doneUtc.add(Duration(days: intervalDays)));
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'intervalDays': intervalDays,
        'nextDueUtc': nextDueUtc.toIso8601String(),
      };

  factory CareTask.fromJson(Map<String, dynamic> json) {
    final kind = careTaskKindFromId(json['kind'] as String? ?? '');
    if (kind == null) {
      throw FormatException('unknown care task kind');
    }
    final nextDue = DateTime.tryParse(json['nextDueUtc'] as String? ?? '');
    if (nextDue == null) {
      throw FormatException('care task missing next due date');
    }
    return CareTask(
      kind: kind,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 30,
      nextDueUtc: nextDue.isUtc ? nextDue : nextDue.toUtc(),
    );
  }
}
