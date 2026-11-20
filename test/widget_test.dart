import 'package:flutter_test/flutter_test.dart';
import 'package:madinati_city_builder/main.dart';

void main() {
  test('city building tools are available', () {
    expect(Tool.home, isNotNull);
    expect(Tool.road, isNotNull);
    expect(Tool.factory, isNotNull);
    expect(Tool.park, isNotNull);
  });
}
