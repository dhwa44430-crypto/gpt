import 'package:flutter_test/flutter_test.dart';
import 'package:qahraman_platformer/main.dart';

void main() {
  testWidgets('يعرض شاشة بداية اللعبة', (WidgetTester tester) async {
    await tester.pumpWidget(const HeroQuestApp());
    expect(find.text('مغامرات البطل'), findsOneWidget);
  });
}
