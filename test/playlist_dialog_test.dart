import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auralis/main.dart';

void main() {
  testWidgets('opens the new playlist dialog and saves its name',
      (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: _DialogHost(
          onResult: (value) => result = value,
          dialog: const PlaylistNameDialog(
            initialName: '',
            title: 'New playlist',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('New playlist'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Road trip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Road trip');
  });

  testWidgets('cancels without returning a playlist name', (tester) async {
    String? result = 'unchanged';
    await tester.pumpWidget(
      MaterialApp(
        home: _DialogHost(
          onResult: (value) => result = value,
          dialog: const PlaylistNameDialog(
            initialName: 'Existing',
            title: 'Edit playlist',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Edit playlist'), findsOneWidget);
    expect(find.text('Existing'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('submits with the keyboard done action', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: _DialogHost(
          onResult: (value) => result = value,
          dialog: const PlaylistNameDialog(
            initialName: '',
            title: 'New playlist',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Workout');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, 'Workout');
  });
}

class _DialogHost extends StatelessWidget {
  const _DialogHost({required this.onResult, required this.dialog});

  final ValueChanged<String?> onResult;
  final Widget dialog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await showDialog<String>(
              context: context,
              builder: (_) => dialog,
            );
            onResult(result);
          },
          child: const Text('Open dialog'),
        ),
      ),
    );
  }
}
