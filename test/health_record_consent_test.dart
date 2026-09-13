import 'package:breedr/models/pet_listing_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('health record preserves clinic consent in draft serialization', () {
    const record = PetHealthRecordData(
      recordId: 'record-1',
      type: 'Vaccination',
      fileName: 'vaccination.png',
      clinic: 'Test Veterinary Clinic',
      clinicConsentGranted: true,
      verificationStatus: 'awaiting_clinic_confirmation',
    );

    final restored = PetHealthRecordData.fromDraftJson(record.toDraftJson());

    expect(restored.clinicConsentGranted, isTrue);
    expect(restored.verificationStatus, 'awaiting_clinic_confirmation');
    expect(record.toMap()['verificationSource'], 'clinic_email');
  });

  test('clinic consent defaults to false for legacy health records', () {
    final restored = PetHealthRecordData.fromDraftJson({
      'recordId': 'legacy',
      'type': 'Deworming',
      'fileName': 'legacy.png',
    });

    expect(restored.clinicConsentGranted, isFalse);
  });
}
