import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/main.dart';

void main() {
  testWidgets('shows the Auralis home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AuralisApp());

    expect(find.text('Your sound,\nyour space.'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Midnight Signals'), findsNWidgets(2));
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('navigates between the main sections', (WidgetTester tester) async {
    await tester.pumpWidget(const AuralisApp());

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('4 songs'), findsOneWidget);

    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    expect(find.text('No playlists yet'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Preferences'), findsOneWidget);
  });

  testWidgets('opens the visual player from a song', (WidgetTester tester) async {
    await tester.pumpWidget(const AuralisApp());

    await tester.tap(find.text('Midnight Signals').first);
    await tester.pumpAndSettle();

    expect(find.text('Now playing'), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
  });
}
