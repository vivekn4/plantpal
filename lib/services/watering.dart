import '../models/plant.dart';

/// How the soil felt at setup. Shifts the first due date (PLAN.md 3).
enum SoilFeel { dry, moist, wet }

/// Pure watering math. No widgets, no storage, no clock — every function
/// takes the "now" it should use, so tests can pin it down.
enum WateringStatus { happy, dueSoon, overdue }

/// The next due date for a plant.
///
/// If the plant has been watered, it is lastWatered + interval.
/// Otherwise the setup-time first due date is used (which already
/// carries the moisture shift); if even that is missing, fall back to
/// created + interval rather than crashing.
DateTime nextDue(Plant plant) {
  final last = plant.lastWateredUtc;
  if (last != null) {
    return last.add(Duration(days: plant.intervalDays));
  }
  final first = plant.firstDueUtc;
  if (first != null) return first;
  return plant.createdUtc.add(Duration(days: plant.intervalDays));
}

/// First due date at setup time, from the species interval and the
/// soil answer. Exactly the PLAN.md rule: dry is 2 days sooner
/// (minimum 1 day), moist is the interval, wet is 2 days later.
DateTime firstDueFromSetup({
  required DateTime setupUtc,
  required int intervalDays,
  required SoilFeel soil,
}) {
  final shifted = switch (soil) {
    SoilFeel.dry => intervalDays - 2 < 1 ? 1 : intervalDays - 2,
    SoilFeel.moist => intervalDays,
    SoilFeel.wet => intervalDays + 2,
  };
  return setupUtc.add(Duration(days: shifted));
}

WateringStatus statusAt(Plant plant, DateTime nowUtc) {
  final due = nextDue(plant);
  if (!nowUtc.isBefore(due)) return WateringStatus.overdue;
  if (due.difference(nowUtc) <= const Duration(hours: 24)) {
    return WateringStatus.dueSoon;
  }
  return WateringStatus.happy;
}

/// Watering streak: how many waterings in a row were on time, ending
/// with the most recent watering. Other apps show streaks and
/// achievements; PlantPal's version is just this number, derived
/// from history, never a made-up score.
///
/// Rules, kept plain: a plant that is overdue right now has a
/// streak of 0 (the streak broke when it went overdue). Otherwise,
/// walk the history backwards: a watering counts when it happened
/// on or before its cycle's due date (the previous watering +
/// interval, or the setup first due date for the first watering).
/// The first late watering stops the count. The current interval
/// is used for every cycle — an approximation when the interval
/// was edited mid-history, stated here so it is not hidden.
int wateringStreak(Plant plant, DateTime nowUtc) {
  if (statusAt(plant, nowUtc) == WateringStatus.overdue) return 0;
  final history = [...plant.wateredHistoryUtc]..sort();
  if (history.isEmpty) return 0;
  var streak = 0;
  for (var i = history.length - 1; i >= 0; i--) {
    final watering = history[i];
    final due = i == 0
        ? (plant.firstDueUtc ?? plant.createdUtc.add(
              Duration(days: plant.intervalDays),
            ))
        : history[i - 1].add(Duration(days: plant.intervalDays));
    if (watering.isAfter(due)) break;
    streak++;
  }
  return streak;
}

/// Whole days past the due date. Zero when overdue by less than a day.
int daysOverdue(Plant plant, DateTime nowUtc) {
  final diff = nowUtc.difference(nextDue(plant));
  if (diff.isNegative) return 0;
  return diff.inDays;
}

/// Plain-words badge for the home shelf. Always text, never colour alone.
String dueBadge(Plant plant, DateTime nowUtc) {
  final due = nextDue(plant);
  final status = statusAt(plant, nowUtc);
  if (status == WateringStatus.overdue) {
    final days = daysOverdue(plant, nowUtc);
    if (days <= 0) return 'Overdue today';
    if (days == 1) return '1 day overdue';
    return '$days days overdue';
  }
  final remaining = due.difference(nowUtc);
  if (status == WateringStatus.dueSoon) {
    if (remaining.inHours < 1) return 'Due within the hour';
    final dueLocal = due.toLocal();
    final nowLocal = nowUtc.toLocal();
    if (dueLocal.day == nowLocal.day &&
        dueLocal.month == nowLocal.month &&
        dueLocal.year == nowLocal.year) {
      return 'Due today';
    }
    return 'Due tomorrow';
  }
  final days = remaining.inDays;
  if (days <= 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due in $days days';
}

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Water on Thursday" — the plant screen's plain-words date.
String nextWateringWords(Plant plant) {
  final local = nextDue(plant).toLocal();
  return 'Water on ${_weekdays[local.weekday - 1]}';
}

/// Short date for history lists, e.g. "Oct 26".
String shortDate(DateTime utc) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = utc.toLocal();
  return '${months[local.month - 1]} ${local.day}';
}

/// Recompute the due date after an interval edit, from the last
/// watered date (or, for a never-watered plant, by shifting the
/// stored estimated first due date by the interval change, so the
/// moisture shift baked into that estimate is preserved).
/// The caller shows old -> new before confirming (PLAN.md bug 9),
/// and must save the returned date as the new first due date for a
/// never-watered plant — otherwise the preview would promise a move
/// the saved plant never makes.
DateTime recomputedDue(Plant plant, int newIntervalDays) {
  final edited = plant.copyWith(intervalDays: newIntervalDays);
  if (plant.lastWateredUtc != null) return nextDue(edited);
  final first = plant.firstDueUtc;
  if (first != null) {
    return first.add(
      Duration(days: newIntervalDays - plant.intervalDays),
    );
  }
  return nextDue(edited);
}
