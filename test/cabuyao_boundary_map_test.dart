import 'package:breedr/widgets/cabuyao_boundary_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline barangay map renders and explains its controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            width: 400,
            child: CabuyaoBoundaryMap(
              locationName: 'Brgy. Niugan, Cabuyao, Laguna',
              latitude: 14.2685,
              longitude: 121.1332,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Find barangay'), findsOneWidget);
    expect(find.text('Show all Cabuyao'), findsOneWidget);
    expect(find.textContaining('Brgy. Niugan'), findsOneWidget);
    expect(find.text('Saved point (precision unknown)'), findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find barangay'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sala');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sala').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Brgy. Sala'), findsOneWidget);
    await tester.tap(find.text('Show all Cabuyao'));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    expect(tester.takeException(), isNull);
  });
}
