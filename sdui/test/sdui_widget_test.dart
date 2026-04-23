import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:platera_app/screens/sdui_customer_screen.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;
  late Map<String, dynamic> mockUiSchema;
  late Map<String, dynamic> mockData;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost:3000/api'));
  });

  setUp(() {
    mockClient = MockClient();
    clearUiSchemaCache();

    mockUiSchema = {
      'type': 'screen',
      'meta': {
        'cachePolicy': {'ttl': 300},
      },
      'appBar': {'type': 'appBar', 'title': 'Customers List'},
      'body': {
        'type': 'column',
        'children': [
          {
            'type': 'searchBar',
            'id': 'search_bar',
            'visible': false,
            'placeholder': 'Search...',
          },
          {
            'type': 'expanded',
            'child': {
              'type': 'list',
              'id': 'customer_list',
              'item': {
                'type': 'card',
                'child': {'type': 'text', 'value': '{name}'},
              },
            },
          },
        ],
      },
    };

    mockData = {
      'data': [
        {'id': '1', 'name': 'Alice'},
        {'id': '2', 'name': 'Bob'},
      ],
    };
  });

  Widget createTestWidget() {
    return MaterialApp(home: SduiCustomerScreen(client: mockClient));
  }

  group('SduiCustomerScreen Widget Tests', () {
    testWidgets('shows skeleton while loading', (tester) async {
      // Use a completer that we NEVER complete during this test
      // to simulate the 'always loading' state without a timer.
      final completer = Completer<http.Response>();
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(createTestWidget());
      // Pump once to trigger initState's _loadAll
      await tester.pump();

      // Should find at least one skeleton-like element (rendered by _buildSkeleton)
      expect(find.byType(ListView), findsOneWidget);
      expect(
        find.byType(RefreshIndicator),
        findsNothing,
      ); // Success UI shouldn't be there
    });

    testWidgets('renders UI and data on success', (tester) async {
      when(
        () => mockClient.get(
          Uri.parse('http://localhost:3000/api/ui/screen/customer-list'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockUiSchema), 200));

      when(
        () => mockClient.get(
          Uri.parse('http://localhost:3000/api/customers/data'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockData), 200));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Customers List'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('toggles search bar visibility', (tester) async {
      // Create a deep copy and modify
      final uiWithToggle = jsonDecode(jsonEncode(mockUiSchema));
      uiWithToggle['appBar']['actions'] = [
        {
          'type': 'iconButton',
          'id': 'search_toggle',
          'icon': 'search',
          'onClick': {'type': 'toggleVisibility', 'target': 'search_bar'},
        },
      ];

      when(
        () => mockClient.get(
          Uri.parse('http://localhost:3000/api/ui/screen/customer-list'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(uiWithToggle), 200));
      when(
        () => mockClient.get(
          Uri.parse('http://localhost:3000/api/customers/data'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockData), 200));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Search bar initially hidden
      expect(find.byType(TextField), findsNothing);

      // Tap toggle
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();

      // Search bar should now be visible
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows error UI and retries', (tester) async {
      // First call fails
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('Error', 500));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('UI schema error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Now set success for retry
      when(
        () => mockClient.get(
          Uri.parse('http://localhost:3000/api/ui/screen/customer-list'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockUiSchema), 200));
      when(
        () => mockClient.get(
          Uri.parse('http://localhost:3000/api/customers/data'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockData), 200));

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
    });
  });
}
