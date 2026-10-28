import '../models/care_task.dart';
import 'watering.dart';

/// Pure care-task math, mirroring watering.dart: every function
/// takes the "now" it should use, so tests can pin it down.

/// A task's status reuses the watering vocabulary: happy, due soon
/// (within 24 hours), overdue. No new words for the user to learn.
WateringStatus careTaskStatus(CareTask task, DateTime nowUtc) {
  final due = task.nextDueUtc;
  if (!nowUtc.isBefore(due)) return WateringStatus.overdue;
  if (due.difference(nowUtc) <= const Duration(hours: 24)) {
    return WateringStatus.dueSoon;
  }
  return WateringStatus.happy;
}

/// Plain-words due line for a task, e.g. "Fertilize in 5 days".
/// Overdue tasks read like the watering badge does.
String careTaskDueWords(CareTask task, DateTime nowUtc) {
  final status = careTaskStatus(task, nowUtc);
  final label = task.kind.label;
  if (status == WateringStatus.overdue) {
    final diff = nowUtc.difference(task.nextDueUtc);
    if (diff.inDays <= 0) return '$label overdue today';
    if (diff.inDays == 1) return '$label 1 day overdue';
    return '$label ${diff.inDays} days overdue';
  }
  final remaining = task.nextDueUtc.difference(nowUtc);
  if (status == WateringStatus.dueSoon) {
    if (remaining.inHours < 1) return '$label within the hour';
    return '$label due tomorrow';
  }
  final days = remaining.inDays;
  if (days <= 0) return '$label due today';
  if (days == 1) return '$label tomorrow';
  return '$label in $days days';
}

/// The most urgent task first, by next due date. Used on the plant
/// screen so the task that needs attention is never buried.
List<CareTask> sortedCareTasks(List<CareTask> tasks) {
  final sorted = [...tasks]
    ..sort((a, b) => a.nextDueUtc.compareTo(b.nextDueUtc));
  return sorted;
}
