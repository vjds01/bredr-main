import 'package:flutter_test/flutter_test.dart';
import 'package:breedr/main.dart';

void main() {
  testWidgets('Breedr app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BreedrApp());
    expect(find.text('Breedr.'), findsWidgets);
  });
}
