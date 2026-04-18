import 'package:flutter_test/flutter_test.dart';
import 'package:fnf_international/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FnFApp());
    expect(find.text('Friend n Friends International'), findsWidgets);
  });
}
