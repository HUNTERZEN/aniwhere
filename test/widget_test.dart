import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aniwhere/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: AniwhereApp(),
      ),
    );

    // Verify the app renders
    expect(find.byType(AniwhereApp), findsOneWidget);
    expect(find.text('Library'), findsWidgets);
  });
}
