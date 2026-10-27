import 'package:flutter_test/flutter_test.dart';
import 'package:plantpal/models/species.dart';

void main() {
  test('every starter species is present', () {
    final ids = speciesTable.map((s) => s.id).toSet();
    expect(
      ids,
      containsAll([
        'pothos',
        'snake-plant',
        'spider-plant',
        'monstera',
        'peace-lily',
        'succulent',
        'fern',
        'fiddle-leaf-fig',
        'philodendron',
        'zz-plant',
        'other',
      ]),
    );
  });

  test('other uses the conservative 7-day default', () {
    expect(speciesById('other').defaultIntervalDays, 7);
    expect(
      speciesById('other').defaultIntervalDays,
      otherSpeciesIntervalDays,
    );
  });

  test('every interval is in 1..60 and every care note is one line', () {
    for (final species in speciesTable) {
      expect(species.defaultIntervalDays, inInclusiveRange(1, 60));
      expect(species.careNote.trim(), isNotEmpty);
      expect(species.careNote.contains('\n'), isFalse);
    }
  });

  test('unknown species ids fall back to other', () {
    expect(speciesById('nope').id, 'other');
  });
}
