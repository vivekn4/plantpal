import '../models/plant.dart';

/// Adaptive learning, on-device only — no model, no cloud, no key.
///
/// This is the version of "AI learning" that fits PlantPal. The app
/// already stores a watering history per plant, so it can learn the
/// user's actual rhythm instead of guessing from a species table:
/// the median gap between real waterings, not the mean (one late
/// watering on holiday should not drag the suggestion around).
///
/// Deliberately NOT here:
/// - No photo identification or disease diagnosis. That needs a
///   labelled dataset and a trained model PlantPal does not have,
///   and a wrong guess about disease would be worse than no guess.
/// - No automatic interval changes. A suggestion is shown, the
///   user taps Apply or leaves it. The schedule never moves
///   behind the user's back.
/// - No weather learning yet. Weather is fetched live and is not
///   stored with each watering, so there is no weather history to
///   learn from. Adding that storage is a future step, not a
///   silent assumption here.
///
/// Rules, stated so they can be tested:
/// - At least 3 gaps (4 waterings) are needed. Fewer than that is
///   not a rhythm, it is a couple of dates.
/// - Same-day repeat waterings (gap 0) are ignored: they are a
///   double-tap, not a rhythm.
/// - The suggestion is the median gap, clamped to 1..60 days.
/// - It is only shown when it differs from the current interval
///   by at least 2 days. A 1-day difference is noise, not learning.

/// Whole-day gaps between successive waterings, in history order.
/// Same-day repeats are dropped.
List<int> wateringGaps(Plant plant) {
  final sorted = [...plant.wateredHistoryUtc]..sort();
  final gaps = <int>[];
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].difference(sorted[i - 1]).inDays;
    if (gap >= 1) gaps.add(gap);
  }
  return gaps;
}

/// Median gap between waterings, or null when there are fewer
/// than 3 gaps. For an even count, the median is the lower of the
/// two middle gaps — rounding toward the current schedule is
/// safer than rounding toward a longer interval.
int? medianGap(Plant plant) {
  final gaps = wateringGaps(plant)..sort();
  if (gaps.length < 3) return null;
  return gaps[(gaps.length - 1) ~/ 2];
}

/// The interval PlantPal has learned from this plant's history,
/// or null when there is not enough history or the learned rhythm
/// is close enough to the current interval that changing it would
/// be noise.
int? suggestedInterval(Plant plant) {
  final median = medianGap(plant);
  if (median == null) return null;
  final clamped = median.clamp(1, 60);
  if ((clamped - plant.intervalDays).abs() < 2) return null;
  return clamped;
}

/// Plain-words description of what has been learned, for the
/// plant screen. Never claims more than the history supports.
String learningText(Plant plant) {
  final median = medianGap(plant);
  if (median == null) {
    final waterings = plant.wateredHistoryUtc.length;
    return 'Learning your rhythm — $waterings '
        '${waterings == 1 ? 'watering' : 'waterings'} so far. '
        'After 4 waterings, PlantPal can suggest a schedule '
        'that matches how you actually water.';
  }
  final suggestion = suggestedInterval(plant);
  if (suggestion == null) {
    return 'Your rhythm matches your schedule: about every '
        '$median days.';
  }
  return 'You usually water about every $median days, not '
      'every ${plant.intervalDays} days.';
}
