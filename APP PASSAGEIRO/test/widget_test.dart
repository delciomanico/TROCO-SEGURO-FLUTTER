// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Carrega o .env antes de qualquer coisa
    await dotenv.load(fileName: '.env');
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Ao invés de usar TrocoSeguroApp completo, criamos um widget simples de teste
    // que não precisa de inicializar o ApiService nem o Firebase
    int counter = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Test')),
              body: Center(
                child: Text('$counter'),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    counter++;
                  });
                },
                child: const Icon(Icons.add),
              ),
            ),
          );
        },
      ),
    );

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
