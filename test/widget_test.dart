import 'package:flutter_test/flutter_test.dart';
import 'package:madinati_city_builder/main.dart';
void main() {
  testWidgets('يعرض واجهة بناء المدينة', (WidgetTester tester) async {
    await tester.pumpWidget(const CityBuilderApp());
    expect(find.text('مدينتي'), findsOneWidget);
    expect(find.text('لوحة البناء'), findsOneWidget);
    expect(find.text('منازل'), findsOneWidget);
    expect(find.text('الطرق'), findsOneWidget);
  });
}
