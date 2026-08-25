import 'package:breedr/widgets/breedr_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Breedr logo renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BreedrLogo(size: 120),
          ),
        ),
      ),
    );

    expect(find.byType(BreedrLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    final asset = image.image as AssetImage;

    expect(asset.assetName, 'assets/images/logo.png');
  });
}