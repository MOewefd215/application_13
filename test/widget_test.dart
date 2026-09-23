import 'package:flutter_test/flutter_test.dart';

import 'package:application_13/main.dart';

void main() {
  testWidgets('app shows the preview title', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentProApp());

    expect(find.text('มือโปรวัยเรียน — UI Preview'), findsOneWidget);
  });
}
