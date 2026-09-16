import 'package:breedr/models/veterinary_clinic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email-capable clinics and demo clinic are centrally configured', () {
    final emailClinics = VeterinaryClinicDirectory.clinics
        .where((clinic) => clinic.supportsEmailVerification)
        .map((clinic) => clinic.id)
        .toSet();

    expect(
      emailClinics,
      containsAll({
        'breedr_demo',
        'cabuyao_animal_clinic',
        'sitio_beterinaryo_cabuyao',
      }),
    );
  });

  test('clinics without email remain listed for vet-admin review', () {
    expect(
      VeterinaryClinicDirectory.clinics.any(
        (clinic) =>
            clinic.id == 'abc_advance_care' &&
            !clinic.supportsEmailVerification,
      ),
      isTrue,
    );
    expect(
      VeterinaryClinicDirectory.clinics.any(
        (clinic) =>
            clinic.id == 'hayop_kalinga' && !clinic.supportsEmailVerification,
      ),
      isTrue,
    );
  });
}
