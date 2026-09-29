import 'package:flutter_test/flutter_test.dart';

import 'package:studentpro_ui/main.dart';

void main() {
  testWidgets('app shows the preview title', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentProApp());

    expect(find.text('มือโปรวัยเรียน — UI Preview'), findsOneWidget);
  });
}
