import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:refrescos_app/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('PreventaApp'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });
}
