import 'package:breedr/services/health_record_date_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 16);

  test('future Date Issued is rejected', () {
    expect(
      HealthRecordDatePolicy.validate(
        type: 'Vaccination',
        dateIssued: DateTime(2026, 9, 17),
        nextUpdate: DateTime(2027, 9, 17),
        today: today,
      ),
      'Date Issued cannot be in the future.',
    );
  });

  test('vaccination update is exactly one year after issue date', () {
    final issued = DateTime(2026, 9, 16);
    final next = HealthRecordDatePolicy.vaccinationNextUpdate(issued);
    expect(next, DateTime(2027, 9, 16));
    expect(
      HealthRecordDatePolicy.validate(
        type: 'Vaccination',
        dateIssued: issued,
        nextUpdate: next,
        today: today,
      ),
      isNull,
    );
  });

  test('deworming update must be after issue date', () {
    expect(HealthRecordDatePolicy.canEditNextUpdate('Deworming'), isTrue);
    expect(
      HealthRecordDatePolicy.validate(
        type: 'Deworming',
        dateIssued: today,
        nextUpdate: today,
        today: today,
      ),
      'Next Update must be later than Date Issued.',
    );
  });

  test('other record types do not retain or require next update', () {
    expect(HealthRecordDatePolicy.requiresNextUpdate('Vet Checkup'), isFalse);
    expect(HealthRecordDatePolicy.requiresNextUpdate('DNA check'), isFalse);
    expect(HealthRecordDatePolicy.requiresNextUpdate('Other'), isFalse);
    expect(
      HealthRecordDatePolicy.validate(
        type: 'Vet Checkup',
        dateIssued: today,
        nextUpdate: null,
        today: today,
      ),
      isNull,
    );
  });

  test('invalid calendar dates are rejected while both formats parse', () {
    expect(HealthRecordDatePolicy.parse('02/31/2026'), isNull);
    expect(HealthRecordDatePolicy.parse('09/16/2026'), DateTime(2026, 9, 16));
    expect(
      HealthRecordDatePolicy.parse('September 16, 2026'),
      DateTime(2026, 9, 16),
    );
  });
}
