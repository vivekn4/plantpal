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
  // Added from the other apps' guides: the most-asked-for
  // houseplants that were missing. Intervals stay conservative
  // starting points, and every note still fits on one line.
  Species(
    id: 'aloe-vera',
    commonName: 'Aloe vera',
    defaultIntervalDays: 21,
    careNote: 'Bright light, very little water. Let soil dry fully.',
  ),
  Species(
    id: 'jade-plant',
    commonName: 'Jade plant',
    defaultIntervalDays: 14,
    careNote: 'Bright light. Water only when soil is dry.',
  ),
  Species(
    id: 'calathea',
    commonName: 'Calathea',
    defaultIntervalDays: 7,
    careNote: 'Indirect light. Likes soil lightly damp, not wet.',
  ),
  Species(
    id: 'rubber-plant',
    commonName: 'Rubber plant',
    defaultIntervalDays: 7,
    careNote: 'Bright indirect light. Water when top soil dries.',
  ),
  Species(
    id: 'dracaena',
    commonName: 'Dracaena',
    defaultIntervalDays: 14,
    careNote: 'Indirect light. Easy to overwater, so wait.',
  ),
  Species(
    id: 'bird-of-paradise',
    commonName: 'Bird of paradise',
    defaultIntervalDays: 7,
    careNote: 'Bright light. Water when top soil feels dry.',
  ),
  Species(
    id: 'english-ivy',
    commonName: 'English ivy',
    defaultIntervalDays: 7,
    careNote: 'Indirect light. Keep soil lightly damp.',
  ),
  Species(
    id: otherSpeciesId,
    commonName: "Other / I don't know",
    defaultIntervalDays: otherSpeciesIntervalDays,
    careNote: 'A safe middle ground. Adjust it once you know your plant.',
  ),
];

/// Id lookup, built once instead of scanning the table on every
/// call (the adopt screen alone looked the same species up three
/// times per reveal).
final Map<String, Species> _speciesById = {
  for (final species in speciesTable) species.id: species,
};

Species speciesById(String id) {
  return _speciesById[id] ?? speciesTable.last;
}
