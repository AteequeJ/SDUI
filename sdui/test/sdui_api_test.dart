import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:platera_app/screens/sdui_customer_screen.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late MockClient mockClient;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost:3000/api'));
  });

  setUp(() {
    mockClient = MockClient();
    clearUiSchemaCache();
  });

  group('API Unit Tests', () {
    test('fetchScreenConfig returns data on success', () async {
      final mockResponse = {
        'meta': {
          'cachePolicy': {'ttl': 60},
        },
        'type': 'screen',
        'appBar': {'title': 'Test'},
      };

      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockResponse), 200));

      final result = await fetchScreenConfig(client: mockClient);

      expect(result['type'], 'screen');
      expect(result['appBar']['title'], 'Test');
      verify(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).called(1);
    });

    test('fetchScreenConfig uses cache if valid', () async {
      final mockResponse = {
        'meta': {
          'cachePolicy': {'ttl': 60},
        },
        'type': 'screen',
      };

      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockResponse), 200));

      // First call - network
      await fetchScreenConfig(client: mockClient);

      // Second call - cache
      final result = await fetchScreenConfig(client: mockClient);

      expect(result['type'], 'screen');
      verify(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).called(1); // Only once
    });

    test('fetchCustomerData returns list of customers', () async {
      final mockResponse = {
        'success': true,
        'data': [
          {'id': '1', 'name': 'John'},
        ],
      };

      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode(mockResponse), 200));

      final result = await fetchCustomerData(client: mockClient);

      expect(result.length, 1);
      expect(result[0]['name'], 'John');
    });

    test('updateCustomerOrders sends POST request', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode({'success': true}), 200),
      );

      await updateCustomerOrders('1', '5', client: mockClient);

      verify(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: jsonEncode({'id': '1', 'orders': '5'}),
        ),
      ).called(1);
    });

    test('throws exception on error status code', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      expect(() => fetchScreenConfig(client: mockClient), throwsException);
    });
  });
}
