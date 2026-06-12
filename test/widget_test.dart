import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LifeShuffleApp());
    expect(find.byType(LifeShuffleApp), findsOneWidget);
  });
}
