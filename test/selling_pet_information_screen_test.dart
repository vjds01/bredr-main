import 'package:breedr/models/pet_listing_data.dart';
import 'package:breedr/screens/pet/selling_pet_information_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const saleListing = PetListingData(
    name: 'Molly',
    purpose: 'Adoption',
    adoptionType: 'FOR SALE',
    price: 2500,
  );

  test('for-sale listing requires confirmation and timestamp', () {
    expect(saleListing.isForSale, isTrue);
    expect(saleListing.hasValidSaleAcknowledgement, isFalse);

    final confirmed = saleListing.copyWith(
      saleRequirementsAcknowledged: true,
      saleRequirementsAcknowledgedAt: DateTime.utc(2026, 9, 11),
    );
    expect(confirmed.hasValidSaleAcknowledgement, isTrue);
  });

  test('free adoption does not require seller acknowledgement', () {
    const freeListing = PetListingData(
      purpose: 'Adoption',
      adoptionType: 'FREE',
    );
    expect(freeListing.hasValidSaleAcknowledgement, isTrue);
  });

  test('acknowledgement survives draft serialization', () {
    final confirmed = saleListing.copyWith(
      saleRequirementsAcknowledged: true,
      saleRequirementsAcknowledgedAt: DateTime.utc(2026, 9, 11, 8, 30),
    );
    final restored = PetListingData.fromDraftJson(confirmed.toDraftJson());

    expect(restored.saleRequirementsAcknowledged, isTrue);
    expect(
      restored.saleRequirementsAcknowledgedAt,
      DateTime.utc(2026, 9, 11, 8, 30),
    );
    expect(restored.hasValidSaleAcknowledgement, isTrue);
  });

  testWidgets('Continue stays disabled until confirmation is checked', (
    tester,
  ) async {
    PetListingData? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: SellingPetInformationScreen(
          petData: saleListing,
          onConfirmed: (data) async => submitted = data,
        ),
      ),
    );

    ElevatedButton button = tester.widget(
      find.byKey(const Key('selling-requirements-continue')),
    );
    expect(button.onPressed, isNull);

    final confirmation = find.byKey(
      const Key('selling-requirements-confirmation'),
    );
    await tester.ensureVisible(confirmation);
    await tester.pumpAndSettle();
    await tester.tap(confirmation);
    await tester.pump();

    button = tester.widget(
      find.byKey(const Key('selling-requirements-continue')),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('selling-requirements-continue')));
    await tester.pumpAndSettle();

    expect(submitted?.saleRequirementsAcknowledged, isTrue);
    expect(submitted?.saleRequirementsAcknowledgedAt, isNotNull);
  });
}
