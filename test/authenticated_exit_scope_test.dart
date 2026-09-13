import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breedr/widgets/authenticated_exit_scope.dart';

void main() {
  testWidgets('back asks before exiting and Stay keeps the app open', (
    tester,
  ) async {
    var exits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedExitScope(
          onExit: () => exits++,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Exit Breedr?'), findsOneWidget);
    expect(find.textContaining('You will remain signed in.'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(exits, 0);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Exit app invokes exit without changing authentication state', (
    tester,
  ) async {
    var exits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedExitScope(
          onExit: () => exits++,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit app'));
    await tester.pumpAndSettle();

    expect(exits, 1);
  });

  testWidgets('beforeExit can consume Back before showing the exit prompt', (
    tester,
  ) async {
    var consumed = 0;
    var exits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedExitScope(
          beforeExit: () {
            consumed++;
            return false;
          },
          onExit: () => exits++,
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(consumed, 1);
    expect(exits, 0);
    expect(find.text('Exit Breedr?'), findsNothing);
  });
}
