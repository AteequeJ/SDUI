import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const String _baseUrl =
    'http://localhost:3000/api'; // 🔁 Replace with your base URL
const String _uiSchemaCacheKey = 'ui_schema_customer_list';

// ─── Models ──────────────────────────────────────────────────────────────────

class UiField {
  final String key;
  final String label;

  UiField({required this.key, required this.label});

  factory UiField.fromJson(Map<String, dynamic> json) =>
      UiField(key: json['key'] as String, label: json['label'] as String);
}

// ─── API Functions ────────────────────────────────────────────────────────────

Future<List<UiField>> fetchUiSchema() async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_uiSchemaCacheKey);

  if (cached != null) {
    final decoded = jsonDecode(cached) as Map<String, dynamic>;
    return _parseFields(decoded);
  }

  final response = await http.get(
    Uri.parse('$_baseUrl/ui/screen/customer-list'),
  );
  if (response.statusCode != 200) throw Exception('Failed to load UI schema');

  await prefs.setString(_uiSchemaCacheKey, response.body);
  return _parseFields(jsonDecode(response.body) as Map<String, dynamic>);
}

List<UiField> _parseFields(Map<String, dynamic> json) {
  final fields = json['fields'] as List<dynamic>;
  return fields
      .map((f) => UiField.fromJson(f as Map<String, dynamic>))
      .toList();
}

Future<List<Map<String, dynamic>>> fetchCustomers() async {
  final response = await http.get(Uri.parse('$_baseUrl/customers'));
  if (response.statusCode != 200) throw Exception('Failed to load customers');

  final data = jsonDecode(response.body);
  // Handle both { "data": [...] } and plain [...]
  if (data is List) return List<Map<String, dynamic>>.from(data);
  if (data is Map && data['data'] is List) {
    return List<Map<String, dynamic>>.from(data['data'] as List);
  }
  throw Exception('Unexpected response format');
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<UiField> _fields = [];
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([fetchUiSchema(), fetchCustomers()]);
      setState(() {
        _fields = results[0] as List<UiField>;
        _customers = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_customers.isEmpty) {
      return const Center(child: Text('No customers found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          final customer = _customers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _fields.map((field) {
                  final value = customer[field.key]?.toString() ?? '—';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${field.label}: ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Expanded(child: Text(value)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}
