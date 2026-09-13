class PetAgeValue {
  const PetAgeValue(this.value, this.unit);

  final int value;
  final String unit;

  static const units = ['years old', 'months old', 'weeks old'];

  int get totalWeeks => switch (unit) {
    'years old' => value * 52,
    'months old' => value * 4,
    _ => value,
  };

  int get totalMonths => switch (unit) {
    'years old' => value * 12,
    'months old' => value,
    _ => value ~/ 4,
  };

  String get displayText => '$value $unit';

  static PetAgeValue? tryParse(String text) {
    final match = RegExp(
      r'^\s*(\d+)\s+(years? old|months? old|weeks? old)\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    if (value == null || value < 1) return null;
    final rawUnit = match.group(2)!.toLowerCase();
    final unit = rawUnit.startsWith('year')
        ? 'years old'
        : rawUnit.startsWith('month')
        ? 'months old'
        : 'weeks old';
    return PetAgeValue(value, unit);
  }
}

class PetEligibilityIssue {
  const PetEligibilityIssue({required this.title, required this.message});

  final String title;
  final String message;
}

class PetEligibilityPolicy {
  const PetEligibilityPolicy._();

  static PetEligibilityIssue? validate({
    required String purpose,
    required PetAgeValue age,
    required String gender,
    required String breedSize,
    String petName = 'This pet',
  }) {
    final normalizedPurpose = purpose.trim().toLowerCase();
    if (normalizedPurpose == 'adoption' && age.totalWeeks < 8) {
      return PetEligibilityIssue(
        title: 'Too Young for Adoption',
        message:
            '$petName is currently ${age.displayText}. Pets must be at least 8 weeks old before they can be listed for adoption.',
      );
    }
    if (normalizedPurpose != 'breeding') return null;
    if (age.totalMonths >= 108) {
      return PetEligibilityIssue(
        title: 'Too Old for Breeding',
        message:
            '$petName is currently ${age.displayText}. Pets aged 9 years or older cannot be listed for breeding.',
      );
    }
    final minimumMonths =
        gender.trim().toLowerCase() == 'female' ||
            breedSize.trim().toLowerCase() == 'large'
        ? 18
        : 12;
    if (age.totalMonths < minimumMonths) {
      return PetEligibilityIssue(
        title: 'Too Young for Breeding',
        message:
            '$petName is currently ${age.displayText}. ${gender.trim()} pets with this breed size must be at least $minimumMonths months old before they can be listed for breeding.',
      );
    }
    return null;
  }

  static int maxForUnit(String unit) => switch (unit) {
    'weeks old' => 520,
    'months old' => 120,
    _ => 10,
  };

  static String oppositeGender(String gender) =>
      gender.trim().toLowerCase() == 'male' ? 'Female' : 'Male';

  static String? validateInterviewQuestions(
    List<Map<String, dynamic>> questions,
  ) {
    if (questions.length > 10) {
      return 'You can add up to 10 adoption questions only.';
    }
    final seen = <String>{};
    for (final question in questions) {
      final text = question['text']?.toString().trim() ?? '';
      if (text.isEmpty) return 'Every adoption question must contain text.';
      if (!seen.add(text.toLowerCase())) {
        return 'Duplicate adoption questions are not allowed.';
      }
      final type = question['type']?.toString() ?? 'textAnswer';
      if (!const {
        'multipleChoice',
        'textAnswer',
        'yesNo',
        'rating',
      }.contains(type)) {
        return 'One adoption question has an invalid answer type.';
      }
      if (type == 'multipleChoice') {
        final choices =
            ((question['choices'] as List?) ??
                    (question['options'] as List?) ??
                    const [])
                .map((choice) => choice.toString().trim())
                .where((choice) => choice.isNotEmpty)
                .toList();
        if (choices.length < 2 ||
            choices.map((choice) => choice.toLowerCase()).toSet().length !=
                choices.length) {
          return 'Multiple-choice questions need at least two different choices.';
        }
      }
    }
    return null;
  }
}
