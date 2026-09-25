import 'package:breedr/services/cabuyao_access_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a central Cabuyao coordinate is inside the service area', () {
    expect(
      CabuyaoAccessService.instance.isWithinCoordinates(14.2726, 121.1266),
      isTrue,
    );
  });

  test('the Santa Rosa GPS-emulator coordinate is outside Cabuyao', () {
    expect(
      CabuyaoAccessService.instance.isWithinCoordinates(14.3122, 121.1114),
      isFalse,
    );
  });
}
