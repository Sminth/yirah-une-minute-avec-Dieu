// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_minute/app/app.dart';

void main() {
  testWidgets('Home renders with verse and duration buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('One Minute'), findsOneWidget);
    expect(find.text('Jean 15:5'), findsOneWidget);
    expect(find.text('1m'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(find.text('10m'), findsOneWidget);
  });
}
