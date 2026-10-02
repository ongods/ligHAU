import 'package:flutter_test/flutter_test.dart';

import 'package:final_project/main.dart';

void main() {
  testWidgets('app starts and shows login screen', (tester) async {
    await tester.pumpWidget(const LigHAUApp());

    expect(find.text('ligHAU'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
