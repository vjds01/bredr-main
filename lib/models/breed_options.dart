class BreedOption {
  final String name;
  final String species;

  const BreedOption(this.name, this.species);
}

const dogBreedOptions = [
  'Aspin',
  'Shih Tzu',
  'Pomeranian',
  'Siberian Husky',
  'Golden Retriever',
  'Labrador Retriever',
  'French Bulldog',
  'Chihuahua',
  'Poodle',
  'Toy Poodle',
  'Miniature Poodle',
  'Beagle',
  'Yorkshire Terrier',
  'Maltese',
  'Dachshund',
  'American Bully',
  'German Shepherd',
  'Rottweiler',
  'Corgi',
  'Jack Russell Terrier',
];

const catBreedOptions = [
  'Puspin',
  'Persian',
  'British Shorthair',
  'Scottish Fold',
  'Siamese',
  'Maine Coon',
  'Ragdoll',
  'Russian Blue',
  'Bengal',
  'American Shorthair',
  'Exotic Shorthair',
  'Domestic Short Hair',
  'Domestic Long Hair',
];

final allBreedOptions = [
  ...dogBreedOptions.map((breed) => BreedOption(breed, 'Dog')),
  ...catBreedOptions.map((breed) => BreedOption(breed, 'Cat')),
];

List<String> breedNamesForSpecies(String species) {
  final normalized = species.trim().toLowerCase();
  if (normalized == 'dog') return dogBreedOptions;
  if (normalized == 'cat') return catBreedOptions;
  return const [];
}

String mixedBreedDisplayName({
  required bool isMixedBreed,
  required String primaryBreed,
  String secondaryBreed = '',
}) {
  final primary = primaryBreed.trim();
  final secondary = secondaryBreed.trim();

  if (!isMixedBreed) return primary;
  if (primary.isEmpty) return 'Mixed Breed';
  if (secondary.isEmpty || secondary == primary) return '$primary Mix';
  return '$primary / $secondary';
}

List<String> breedTagsFor({
  required bool isMixedBreed,
  required String primaryBreed,
  String secondaryBreed = '',
}) {
  final tags = <String>[];
  void add(String value) {
    final cleaned = value.trim();
    if (cleaned.isNotEmpty && !tags.contains(cleaned)) tags.add(cleaned);
  }

  add(primaryBreed);
  if (isMixedBreed) {
    add(secondaryBreed);
    add('Mixed Breed');
  }
  return tags;
}
