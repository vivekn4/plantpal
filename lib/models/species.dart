/// Offline species table, shipped in the app. Hand-written starter set
/// only — intervals are starting points the user can adjust per plant.
/// No scraped or copied data lives here.
class Species {
  const Species({
    required this.id,
    required this.commonName,
    required this.defaultIntervalDays,
    required this.careNote,
  });

  final String id;
  final String commonName;
  final int defaultIntervalDays;
  final String careNote;
}

const String otherSpeciesId = 'other';

/// Conservative default used for "Other / I don't know" (see PLAN.md).
const int otherSpeciesIntervalDays = 7;

const List<Species> speciesTable = [
  Species(
    id: 'pothos',
    commonName: 'Pothos',
    defaultIntervalDays: 7,
    careNote: 'Lets the top soil dry out between drinks.',
  ),
  Species(
    id: 'snake-plant',
    commonName: 'Snake plant',
    defaultIntervalDays: 14,
    careNote: 'Happy to be left alone. Easy to overwater.',
  ),
  Species(
    id: 'spider-plant',
    commonName: 'Spider plant',
    defaultIntervalDays: 7,
    careNote: 'Likes a drink when the top soil feels dry.',
  ),
  Species(
    id: 'monstera',
    commonName: 'Monstera',
    defaultIntervalDays: 7,
    careNote: 'Water when the top few centimetres are dry.',
  ),
  Species(
    id: 'peace-lily',
    commonName: 'Peace lily',
    defaultIntervalDays: 7,
    careNote: 'Droops a little when thirsty, perks up after water.',
  ),
  Species(
    id: 'succulent',
    commonName: 'Succulent / cactus',
    defaultIntervalDays: 14,
    careNote: 'Needs very little water. When in doubt, wait.',
  ),
  Species(
    id: 'fern',
    commonName: 'Fern',
    defaultIntervalDays: 4,
    careNote: 'Likes soil that stays lightly damp.',
  ),
  Species(
    id: 'fiddle-leaf-fig',
    commonName: 'Fiddle-leaf fig',
    defaultIntervalDays: 7,
    careNote: 'Steady routine suits it best.',
  ),
  Species(
    id: 'philodendron',
    commonName: 'Philodendron',
    defaultIntervalDays: 7,
    careNote: 'Water when the top soil feels dry.',
  ),
  Species(
    id: 'zz-plant',
    commonName: 'ZZ plant',
    defaultIntervalDays: 14,
    careNote: 'Stores water in its roots. Easy to overwater.',
  ),
  Species(
    id: otherSpeciesId,
    commonName: "Other / I don't know",
    defaultIntervalDays: otherSpeciesIntervalDays,
    careNote: 'A safe middle ground. Adjust it once you know your plant.',
  ),
];

Species speciesById(String id) {
  for (final species in speciesTable) {
    if (species.id == id) return species;
  }
  return speciesTable.last;
}
