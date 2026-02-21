import 'package:flutter_test/flutter_test.dart';
import 'package:task_commander/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SongWorkApp());
    expect(find.byType(SongWorkApp), findsOneWidget);
  });
}
