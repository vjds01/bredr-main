import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('published adoption routes to the adoption home tab', () {
    final publishedSource = File(
      'lib/screens/pet/pet_published_screen.dart',
    ).readAsStringSync();
    final homeSource = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(publishedSource, contains('initialTabIndex: isAdoption ? 1 : 0'));
    expect(homeSource, contains('this.initialTabIndex = 0'));
    expect(
      homeSource,
      contains('_selectedIndex = widget.initialTabIndex.clamp(0, 4)'),
    );
  });
}
