import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sdui/sdui_customer_screen.dart';

// class MockClient extends Mock implements http.Client {}

void main() {
  // late MockClient mockClient;

  setUpAll(() {
    // registerFallbackValue(Uri.parse('http://localhost:3000/api'));
  });

  setUp(() {
    // mockClient = MockClient();
    clearUiSchemaCache();
  });

/*
  Widget createTestWidget(Map<String, dynamic> schema, List<Map<String, dynamic>> data) {
    return MaterialApp(
      home: Scaffold(
        body: SduiCustomerScreen(client: null),
      ),
    );
  }

  group('OrderCounter Behavior Tests', () {
    testWidgets('increments and decrements locally and triggers API', (tester) async {
      // ... test implementation ...
    });
  });
*/
}
