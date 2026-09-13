import 'package:breedr/services/pet_eligibility_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('breeding partner gender', () {
    test('always derives the opposite gender', () {
      expect(PetEligibilityPolicy.oppositeGender('Male'), 'Female');
      expect(PetEligibilityPolicy.oppositeGender('Female'), 'Male');
    });
  });

  group('pet eligibility boundaries', () {
    test('adoption rejects seven weeks and accepts eight weeks', () {
      expect(
        PetEligibilityPolicy.validate(
          purpose: 'adoption',
          age: const PetAgeValue(7, 'weeks old'),
          gender: 'Male',
          breedSize: 'Small',
        )?.title,
        'Too Young for Adoption',
      );
      expect(
        PetEligibilityPolicy.validate(
          purpose: 'adoption',
          age: const PetAgeValue(8, 'weeks old'),
          gender: 'Male',
          breedSize: 'Small',
        ),
        isNull,
      );
    });

    test('small male breeding boundary is twelve months', () {
      expect(
        PetEligibilityPolicy.validate(
          purpose: 'breeding',
          age: const PetAgeValue(11, 'months old'),
          gender: 'Male',
          breedSize: 'Small',
        ),
        isNotNull,
      );
      expect(
        PetEligibilityPolicy.validate(
          purpose: 'breeding',
          age: const PetAgeValue(12, 'months old'),
          gender: 'Male',
          breedSize: 'Small',
        ),
        isNull,
      );
    });

    test('female and large-pet breeding boundary is eighteen months', () {
      for (final caseData in [('Female', 'Small'), ('Male', 'Large')]) {
        expect(
          PetEligibilityPolicy.validate(
            purpose: 'breeding',
            age: const PetAgeValue(17, 'months old'),
            gender: caseData.$1,
            breedSize: caseData.$2,
          ),
          isNotNull,
        );
        expect(
          PetEligibilityPolicy.validate(
            purpose: 'breeding',
            age: const PetAgeValue(18, 'months old'),
            gender: caseData.$1,
            breedSize: caseData.$2,
          ),
          isNull,
        );
      }
    });

    test('breeding rejects nine years and older', () {
      expect(
        PetEligibilityPolicy.validate(
          purpose: 'breeding',
          age: const PetAgeValue(9, 'years old'),
          gender: 'Male',
          breedSize: 'Small',
        )?.title,
        'Too Old for Breeding',
      );
    });
  });

  group('structured interview questions', () {
    test('rejects invalid types, duplicates and invalid choices', () {
      expect(
        PetEligibilityPolicy.validateInterviewQuestions([
          {'type': 'unknown', 'text': 'Question?', 'choices': <String>[]},
        ]),
        contains('invalid answer type'),
      );
      expect(
        PetEligibilityPolicy.validateInterviewQuestions([
          {'type': 'yesNo', 'text': 'Same?', 'choices': <String>[]},
          {'type': 'textAnswer', 'text': 'same?', 'choices': <String>[]},
        ]),
        contains('Duplicate'),
      );
      expect(
        PetEligibilityPolicy.validateInterviewQuestions([
          {
            'type': 'multipleChoice',
            'text': 'Choose',
            'choices': ['Only one'],
          },
        ]),
        contains('at least two'),
      );
    });

    test('accepts a valid structured question set', () {
      expect(
        PetEligibilityPolicy.validateInterviewQuestions([
          {'type': 'yesNo', 'text': 'Do you have pets?', 'choices': <String>[]},
          {
            'type': 'multipleChoice',
            'text': 'Home type?',
            'choices': ['House', 'Apartment'],
          },
        ]),
        isNull,
      );
    });
  });
}
