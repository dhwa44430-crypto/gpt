import 'package:flutter_test/flutter_test.dart';
import 'package:worm_arena/main.dart';

void main() {
  testWidgets('Worm Arena opens with skin selection', (tester) async {
    await tester.pumpWidget(const WormArenaApp());
    expect(find.text('WORM ARENA'), findsOneWidget);
    expect(find.text('CHOOSE YOUR WORM'), findsOneWidget);
    expect(find.text('Lime'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
