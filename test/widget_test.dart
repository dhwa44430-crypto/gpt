import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_escape/main.dart';

void main() {
  testWidgets('Arrow Escape opens its game screen', (tester) async {
    await tester.pumpWidget(const ArrowEscapeApp());
    expect(find.text('CLEAR IT!'), findsOneWidget);
    expect(find.text('اضغط على سهم طريقه مفتوح للخروج'), findsOneWidget);
  });
}
