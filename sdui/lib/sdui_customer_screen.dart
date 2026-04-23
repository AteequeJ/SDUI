import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;

// ─── Constants ────────────────────────────────────────────────────────────────

const String _baseUrl = 'http://localhost:3000/api';

// ─── Cache ────────────────────────────────────────────────────────────────────

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiry;
  const _CacheEntry(this.data, this.expiry);
  bool get isValid => DateTime.now().isBefore(expiry);
}

// ─── API ─────────────────────────────────────────────────────────────────────

_CacheEntry? _uiSchemaCache;

/// Resets the UI schema cache (useful for tests).
void clearUiSchemaCache() => _uiSchemaCache = null;

/// Fetches the UI-only schema from /ui/screen/customer-list.
/// Uses in-memory cache; TTL is read from meta.cachePolicy.ttl (default 300s).
Future<Map<String, dynamic>> fetchScreenConfig({dynamic client}) async {
  // Reading from local data folder
  final String response = await rootBundle.loadString(
    'lib/data/customer_ui_schema.json',
  );
  final data = jsonDecode(response) as Map<String, dynamic>;
  return data;

  /*
  final httpClient = client ?? http.Client();
  try {
    if (_uiSchemaCache != null && _uiSchemaCache!.isValid) {
      return _uiSchemaCache!.data;
    }
    final response = await httpClient.get(
      Uri.parse('$_baseUrl/ui/screen/customer-list'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('UI schema error (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ttl =
        ((data['meta']?['cachePolicy']?['ttl']) as num?)?.toInt() ?? 300;
    _uiSchemaCache = _CacheEntry(data, DateTime.now().add(Duration(seconds: ttl)));
    return data;
  } finally {
    if (client == null) httpClient.close();
  }
  */
}

/// Fetches live customer data — never cached.
Future<List<Map<String, dynamic>>> fetchCustomerData({
  dynamic client,
}) async {
  // Reading from local data folder
  final String response = await rootBundle.loadString(
    'lib/data/customer_data.json',
  );
  final List<dynamic> list = jsonDecode(response) as List<dynamic>;
  return List<Map<String, dynamic>>.from(list);

  /*
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient.get(
      Uri.parse('$_baseUrl/customers/data'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Customer data error (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['data'] as List<dynamic>?) ?? [];
    return List<Map<String, dynamic>>.from(list);
  } finally {
    if (client == null) httpClient.close();
  }
  */
}

/// POSTs an order update, then the caller re-fetches data only.
Future<void> updateCustomerOrders(
  String id,
  String orders, {
  dynamic client,
}) async {
  // Mocking update since we are using local static files
  return;

  /*
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient.post(
      Uri.parse('$_baseUrl/customers/update-orders'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'id': id, 'orders': orders}),
    );
    if (response.statusCode != 200) {
      throw Exception('Update failed (${response.statusCode})');
    }
  } finally {
    if (client == null) httpClient.close();
  }
  */
}

// ─── SduiContext ──────────────────────────────────────────────────────────────
/// Passed through the entire widget tree so stateless renderers can
/// trigger state changes (reload, toggle visibility) back in the screen.

class SduiContext {
  final BuildContext buildContext;
  final void Function(Map<String, String> params) reload;
  final Map<String, String> currentParams;
  final Set<String> visibleWidgets;
  final void Function(String id) toggleVisibility;

  /// Keyed by list node `id` → live data rows injected from the screen state.
  /// The list renderer prefers this over any inline `data` in the schema.
  final Map<String, List<Map<String, dynamic>>> listData;

  /// Called when a card action wants to update orders.
  /// Runs the POST and then re-fetches data only (UI stays cached).
  final Future<void> Function(String id, String orders) onUpdateOrders;

  const SduiContext({
    required this.buildContext,
    required this.reload,
    required this.currentParams,
    required this.visibleWidgets,
    required this.toggleVisibility,
    required this.listData,
    required this.onUpdateOrders,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class SduiCustomerScreen extends StatefulWidget {
  final dynamic client;
  const SduiCustomerScreen({super.key, this.client});

  @override
  State<SduiCustomerScreen> createState() => _SduiCustomerScreenState();
}

class _SduiCustomerScreenState extends State<SduiCustomerScreen> {
  Map<String, dynamic>? _config; // UI schema — cached
  List<Map<String, dynamic>> _customers = []; // data — always fresh
  bool _isLoading = true;
  bool _isDataRefreshing = false; // silent data-only refresh
  String? _error;
  final Set<String> _visibleWidgets = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── First load: UI (cached) + data in parallel ───────────────────────────

  Future<void> _loadAll() async {
    if (mounted)
      setState(() {
        _isLoading = true;
        _error = null;
      });
    try {
      final results = await Future.wait([
        fetchScreenConfig(client: widget.client),
        fetchCustomerData(client: widget.client),
      ]);
      if (mounted) {
        setState(() {
          _config = results[0] as Map<String, dynamic>;
          _customers = results[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Data-only refresh (UI stays cached) ──────────────────────────────────

  Future<void> _loadData() async {
    if (mounted) setState(() => _isDataRefreshing = true);
    try {
      final data = await fetchCustomerData(client: widget.client);
      if (mounted) setState(() => _customers = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDataRefreshing = false);
    }
  }

  // ── Update orders → re-fetch data only ───────────────────────────────────

  Future<void> _updateOrders(String id, String orders) async {
    await updateCustomerOrders(id, orders, client: widget.client);
    await _loadData(); // UI schema is not touched
  }

  // Triggered by filter chips / search
  void _reload(Map<String, String> newParams) => _loadData();

  void _toggleVisibility(String id) {
    setState(() {
      _visibleWidgets.contains(id)
          ? _visibleWidgets.remove(id)
          : _visibleWidgets.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    if (_error != null) return _buildError();
    if (_config == null) return const SizedBox.shrink();

    final ctx = SduiContext(
      buildContext: context,
      reload: _reload,
      currentParams: const {},
      visibleWidgets: _visibleWidgets,
      toggleVisibility: _toggleVisibility,
      // Inject live customer data under the list node id 'customer_list'
      listData: {'customer_list': _customers},
      onUpdateOrders: _updateOrders,
    );

    return RefreshIndicator(
      color: const Color(0xFF6366F1),
      onRefresh: _loadData,
      child: Stack(
        children: [
          SduiRenderer.render(ctx, _config!),
          // Thin progress bar during silent data refresh
          if (_isDataRefreshing)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: Color(0xFF6366F1),
            ),
        ],
      ),
    );
  }

  // ── Skeleton loading ──────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(100, 16),
            const SizedBox(height: 4),
            _shimmerBox(50, 11),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const _SkeletonCard(),
      ),
    );
  }

  static Widget _shimmerBox(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(6),
    ),
  );

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton card ────────────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static Widget _box(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(6),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(140, 14),
                  const SizedBox(height: 8),
                  _box(100, 12),
                ],
              ),
            ),
            _box(64, 26),
          ],
        ),
      ),
    );
  }
}

// ─── Search bar widget ────────────────────────────────────────────────────────

class _SduiSearchBar extends StatefulWidget {
  final String placeholder;
  final double borderRadius;
  final Color backgroundColor;
  final String? initialValue;
  final void Function(String query) onSearch;

  const _SduiSearchBar({
    required this.placeholder,
    required this.borderRadius,
    required this.backgroundColor,
    required this.onSearch,
    this.initialValue,
  });

  @override
  State<_SduiSearchBar> createState() => _SduiSearchBarState();
}

class _SduiSearchBarState extends State<_SduiSearchBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onSubmitted: widget.onSearch,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Colors.grey,
          size: 20,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
          onPressed: () {
            _ctrl.clear();
            widget.onSearch('');
          },
        ),
        filled: true,
        fillColor: widget.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

// ─── SDUI Renderer ────────────────────────────────────────────────────────────
///
/// Widget vocabulary supported:
///   screen | appBar | column | row | expanded | spacer
///   container | list | card (legacy) | text | badge | avatar
///   searchBar | chipGroup | emptyState | fab
///
/// Action types: navigate | toggleVisibility | reload
///
/// Placeholder binding: {key} and {a.b} (nested) resolved from item data.
///

class SduiRenderer {
  // ── Entry point (screen-level, no item data) ──────────────────────────────

  static Widget render(SduiContext ctx, Map<String, dynamic>? node) {
    if (node == null) return const SizedBox.shrink();
    final type = node['type'] as String? ?? '';
    switch (type) {
      case 'screen':
        return _buildScreen(ctx, node);
      case 'column':
        return _buildColumn(ctx, node);
      case 'row':
        return _buildRow(ctx, node, const {});
      case 'expanded':
        return _buildExpanded(ctx, node, const {});
      case 'spacer':
        return _buildSpacer(node);
      case 'list':
        return _buildList(ctx, node);
      case 'container':
        return _buildContainer(ctx, node);
      case 'card':
        return _buildCard(ctx, node, const {});
      case 'text':
        return _buildText(node);
      case 'badge':
        return _buildBadge(node);
      case 'avatar':
        return _buildAvatar(node);
      case 'searchBar':
        return _buildSearchBar(ctx, node);
      case 'chipGroup':
        return _buildChipGroup(ctx, node);
      case 'emptyState':
        return _buildEmptyState(node);
      case 'orderCounter':
        return _buildOrderCounter(ctx, node, const {});
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Data-aware render (inside list items) ─────────────────────────────────

  static Widget _renderWithData(
    SduiContext ctx,
    Map<String, dynamic>? node,
    Map<String, dynamic> data,
  ) {
    if (node == null) return const SizedBox.shrink();
    final type = node['type'] as String? ?? '';
    switch (type) {
      case 'text':
        return _buildText(node, data: data);
      case 'badge':
        return _buildBadge(node, data: data);
      case 'avatar':
        return _buildAvatar(node, data: data);
      case 'spacer':
        return _buildSpacer(node);
      case 'row':
        return _buildRow(ctx, node, data);
      case 'column':
        return _buildColumnWithData(ctx, node, data);
      case 'expanded':
        return _buildExpanded(ctx, node, data);
      case 'container':
        return _buildContainer(ctx, node, data: data);
      case 'card':
        return _buildCard(ctx, node, data);
      case 'orderCounter':
        return _buildOrderCounter(ctx, node, data);
      default:
        return render(ctx, node);
    }
  }

  // ── screen ────────────────────────────────────────────────────────────────

  static Widget _buildScreen(SduiContext ctx, Map<String, dynamic> node) {
    final appBarNode = node['appBar'] as Map<String, dynamic>?;
    final bodyNode = node['body'] as Map<String, dynamic>?;
    final fabNode = node['floatingAction'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: appBarNode != null ? _buildAppBar(ctx, appBarNode) : null,
      body: bodyNode != null ? render(ctx, bodyNode) : null,
      floatingActionButton: fabNode != null ? _buildFab(ctx, fabNode) : null,
    );
  }

  // ── appBar ────────────────────────────────────────────────────────────────

  static PreferredSizeWidget _buildAppBar(
    SduiContext ctx,
    Map<String, dynamic> node,
  ) {
    final title = node['title'] as String? ?? '';
    final subtitle = node['subtitle'] as String?;
    final actions = (node['actions'] as List<dynamic>?) ?? [];
    final bgColor = node['backgroundColor'] != null
        ? _hexColor(node['backgroundColor'] as String)
        : Colors.white;
    final fgColor = node['foregroundColor'] != null
        ? _hexColor(node['foregroundColor'] as String)
        : const Color(0xFF1A1A2E);
    final elevation = (node['elevation'] as num?)?.toDouble() ?? 0;

    return AppBar(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: elevation,
      surfaceTintColor: Colors.transparent,
      title: subtitle != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: fgColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: fgColor.withOpacity(0.55),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: fgColor),
            ),
      actions: actions
          .map((a) => _buildAppBarAction(ctx, a as Map<String, dynamic>))
          .toList(),
    );
  }

  static Widget _buildAppBarAction(SduiContext ctx, Map<String, dynamic> node) {
    final icon = _resolveIcon(node['icon'] as String? ?? 'more_vert');
    final tooltip = node['tooltip'] as String?;
    final onClick = node['onClick'] as Map<String, dynamic>?;
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: () => _handleAction(ctx, onClick, const {}),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────

  static Widget _buildFab(SduiContext ctx, Map<String, dynamic> node) {
    final icon = _resolveIcon(node['icon'] as String? ?? 'add');
    final label = node['label'] as String?;
    final style = node['style'] as Map<String, dynamic>?;
    final bgColor = style?['backgroundColor'] != null
        ? _hexColor(style!['backgroundColor'] as String)
        : const Color(0xFF6366F1);
    final fgColor = style?['foregroundColor'] != null
        ? _hexColor(style!['foregroundColor'] as String)
        : Colors.white;
    final radius = (style?['borderRadius'] as num?)?.toDouble() ?? 16;
    final onClick = node['onClick'] as Map<String, dynamic>?;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    if (label != null) {
      return FloatingActionButton.extended(
        onPressed: () => _handleAction(ctx, onClick, const {}),
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        shape: shape,
        elevation: 4,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return FloatingActionButton(
      onPressed: () => _handleAction(ctx, onClick, const {}),
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      shape: shape,
      elevation: 4,
      child: Icon(icon),
    );
  }

  // ── column ────────────────────────────────────────────────────────────────

  static Widget _buildColumn(SduiContext ctx, Map<String, dynamic> node) {
    final children = (node['children'] as List<dynamic>?) ?? [];
    final style = node['style'] as Map<String, dynamic>?;
    final crossAxis = _resolveCrossAxis(
      style?['crossAxisAlignment'] as String?,
    );
    final mainAxisSize = node['mainAxisSize'] == 'max'
        ? MainAxisSize.max
        : MainAxisSize.min;

    return Column(
      crossAxisAlignment: crossAxis,
      mainAxisSize: mainAxisSize,
      children: children
          .map((c) => render(ctx, c as Map<String, dynamic>?))
          .toList(),
    );
  }

  static Widget _buildColumnWithData(
    SduiContext ctx,
    Map<String, dynamic> node,
    Map<String, dynamic> data,
  ) {
    final children = (node['children'] as List<dynamic>?) ?? [];
    final style = node['style'] as Map<String, dynamic>?;
    final crossAxis = _resolveCrossAxis(
      style?['crossAxisAlignment'] as String?,
    );

    return Column(
      crossAxisAlignment: crossAxis,
      mainAxisSize: MainAxisSize.min,
      children: children
          .map((c) => _renderWithData(ctx, c as Map<String, dynamic>?, data))
          .toList(),
    );
  }

  // ── row ───────────────────────────────────────────────────────────────────

  static Widget _buildRow(
    SduiContext ctx,
    Map<String, dynamic> node,
    Map<String, dynamic> data,
  ) {
    final children = (node['children'] as List<dynamic>?) ?? [];
    final style = node['style'] as Map<String, dynamic>?;
    final crossAxis = _resolveCrossAxis(
      style?['crossAxisAlignment'] as String?,
    );

    return Row(
      crossAxisAlignment: crossAxis,
      children: children
          .map((c) => _renderWithData(ctx, c as Map<String, dynamic>?, data))
          .toList(),
    );
  }

  // ── expanded ──────────────────────────────────────────────────────────────

  static Widget _buildExpanded(
    SduiContext ctx,
    Map<String, dynamic> node,
    Map<String, dynamic> data,
  ) {
    final child = node['child'] as Map<String, dynamic>?;
    final flex = node['flex'] as int? ?? 1;
    return Expanded(
      flex: flex,
      child: data.isEmpty
          ? render(ctx, child)
          : _renderWithData(ctx, child, data),
    );
  }

  // ── spacer ────────────────────────────────────────────────────────────────

  static Widget _buildSpacer(Map<String, dynamic> node) {
    final w = (node['width'] as num?)?.toDouble();
    final h = (node['height'] as num?)?.toDouble();
    if (w != null || h != null) return SizedBox(width: w, height: h);
    return const Spacer();
  }

  // ── container ─────────────────────────────────────────────────────────────

  static Widget _buildContainer(
    SduiContext ctx,
    Map<String, dynamic> node, {
    Map<String, dynamic> data = const {},
  }) {
    final style = node['style'] as Map<String, dynamic>?;
    final childNode = node['child'] as Map<String, dynamic>?;
    final onClick = node['onClick'] as Map<String, dynamic>?;

    final bgRaw = style?['backgroundColor'] as String?;
    final bgColor = bgRaw != null
        ? _hexColor(_resolve(bgRaw, data))
        : Colors.white;
    final borderRadius = (style?['borderRadius'] as num?)?.toDouble() ?? 0;
    final padding = _resolvePadding(style?['padding']);
    final margin = _resolvePadding(style?['margin']);
    final shadowNode = style?['shadow'] as Map<String, dynamic>?;

    Widget content = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadowNode != null ? [_resolveBoxShadow(shadowNode)] : null,
      ),
      child: childNode != null ? _renderWithData(ctx, childNode, data) : null,
    );

    if (onClick != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: () => _handleAction(ctx, onClick, data),
          child: content,
        ),
      );
    }
    return content;
  }

  // ── list ──────────────────────────────────────────────────────────────────

  static Widget _buildList(SduiContext ctx, Map<String, dynamic> node) {
    final listId = node['id'] as String?;

    // Prefer live data injected by the screen (via ctx.listData) over
    // any inline data in the schema JSON.
    final List<dynamic> items =
        (listId != null && ctx.listData.containsKey(listId))
        ? ctx.listData[listId]!
        : ((node['data'] as List<dynamic>?) ??
              (node['items'] as List<dynamic>?) ??
              []);

    final tpl = (node['itemTemplate'] ?? node['item']) as Map<String, dynamic>?;
    final emptyNode = node['emptyState'] as Map<String, dynamic>?;
    final style = node['style'] as Map<String, dynamic>?;
    final padding =
        _resolvePadding(style?['padding']) ?? const EdgeInsets.all(16);

    if (tpl == null) return const SizedBox.shrink();

    if (items.isEmpty && emptyNode != null) {
      return _buildEmptyState(emptyNode);
    }

    return ListView.builder(
      padding: padding,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final rowData = Map<String, dynamic>.from(items[i] as Map? ?? {});
        return _renderWithData(ctx, tpl, rowData);
      },
    );
  }

  // ── card (legacy) ─────────────────────────────────────────────────────────

  static Widget _buildCard(
    SduiContext ctx,
    Map<String, dynamic> node,
    Map<String, dynamic> data,
  ) {
    final style = node['style'] as Map<String, dynamic>?;
    final padding = (node['padding'] as num?)?.toDouble() ?? 14;
    final marginBottom = (node['margin']?['bottom'] as num?)?.toDouble() ?? 12;
    final bgRaw = style?['backgroundColor'] as String?;
    final bgColor = bgRaw != null
        ? _hexColor(_resolve(bgRaw, data))
        : Colors.white;
    final onClick = node['onClick'] as Map<String, dynamic>?;

    final childNode = node['child'] as Map<String, dynamic>?;
    final childrenRows = (node['children'] as List<dynamic>?) ?? [];

    Widget cardBody;
    if (childNode != null) {
      cardBody = _renderWithData(ctx, childNode, data);
    } else {
      cardBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: childrenRows
            .map((c) => _renderWithData(ctx, c as Map<String, dynamic>?, data))
            .toList(),
      );
    }

    Widget card = Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: cardBody),
    );

    if (onClick != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleAction(ctx, onClick, data),
          child: card,
        ),
      );
    }
    return card;
  }

  // ── text ──────────────────────────────────────────────────────────────────

  static Widget _buildText(
    Map<String, dynamic> node, {
    Map<String, dynamic> data = const {},
  }) {
    final value = _resolve(node['value'], data);
    final style = node['style'] as Map<String, dynamic>?;
    final colorRaw = style?['color'] as String?;

    return Text(
      value,
      style: TextStyle(
        fontSize: (style?['fontSize'] as num?)?.toDouble() ?? 14,
        fontWeight: _resolveFontWeight(style?['fontWeight'] as String?),
        color: colorRaw != null ? _hexColor(_resolve(colorRaw, data)) : null,
        letterSpacing: (style?['letterSpacing'] as num?)?.toDouble(),
        height: (style?['lineHeight'] as num?)?.toDouble(),
      ),
    );
  }

  // ── badge ─────────────────────────────────────────────────────────────────

  static Widget _buildBadge(
    Map<String, dynamic> node, {
    Map<String, dynamic> data = const {},
  }) {
    final value = _resolve(node['value'], data);
    final style = node['style'] as Map<String, dynamic>?;

    final bgRaw = style?['backgroundColor'] as String?;
    final bgColor = bgRaw != null
        ? _hexColor(_resolve(bgRaw, data))
        : const Color(0xFF9CA3AF);

    final txtRaw = style?['textColor'] as String?;
    final textColor = txtRaw != null ? _hexColor(txtRaw) : Colors.white;

    final fontSize = (style?['fontSize'] as num?)?.toDouble() ?? 11;
    final borderRadius = (style?['borderRadius'] as num?)?.toDouble() ?? 20;
    final hPad = (style?['padding']?['horizontal'] as num?)?.toDouble() ?? 10;
    final vPad = (style?['padding']?['vertical'] as num?)?.toDouble() ?? 4;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: _resolveFontWeight(style?['fontWeight'] as String?),
        ),
      ),
    );
  }

  // ── avatar ────────────────────────────────────────────────────────────────

  static Widget _buildAvatar(
    Map<String, dynamic> node, {
    Map<String, dynamic> data = const {},
  }) {
    final initials = _resolve(node['initials'] as String? ?? '', data);
    final size = (node['size'] as num?)?.toDouble() ?? 48;
    final style = node['style'] as Map<String, dynamic>?;
    final imageUrl = node['imageUrl'] as String?;

    final bgRaw = style?['backgroundColor'] as String?;
    final bgColor = bgRaw != null
        ? _hexColor(_resolve(bgRaw, data))
        : const Color(0xFF6366F1);
    final textColor = style?['textColor'] != null
        ? _hexColor(style!['textColor'] as String)
        : Colors.white;
    final fontSize = (style?['fontSize'] as num?)?.toDouble() ?? size * 0.35;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: imageUrl == null ? bgColor : null,
        shape: BoxShape.circle,
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: textColor,
                  fontSize: fontSize,
                  fontWeight: _resolveFontWeight(
                    style?['fontWeight'] as String? ?? 'bold',
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ── searchBar ─────────────────────────────────────────────────────────────

  static Widget _buildSearchBar(SduiContext ctx, Map<String, dynamic> node) {
    final id = node['id'] as String? ?? 'search_bar';
    // Server sets initial visibility; client toggles on top.
    final serverVisible = node['visible'] as bool? ?? false;
    final isVisible = ctx.visibleWidgets.contains(id)
        ? !serverVisible
        : serverVisible;
    if (!isVisible) return const SizedBox.shrink();

    final placeholder = node['placeholder'] as String? ?? 'Search…';
    final style = node['style'] as Map<String, dynamic>?;
    final margin =
        _resolvePadding(style?['margin']) ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    final borderRadius = (style?['borderRadius'] as num?)?.toDouble() ?? 12;
    final bgColor = style?['backgroundColor'] != null
        ? _hexColor(style!['backgroundColor'] as String)
        : const Color(0xFFF5F5F5);
    final onSearch = node['onSearch'] as Map<String, dynamic>?;
    final queryParam = onSearch?['queryParam'] as String? ?? 'search';

    return Padding(
      padding: margin,
      child: _SduiSearchBar(
        placeholder: placeholder,
        borderRadius: borderRadius,
        backgroundColor: bgColor,
        initialValue: ctx.currentParams[queryParam],
        onSearch: (query) {
          final p = Map<String, String>.from(ctx.currentParams);
          if (query.isEmpty) {
            p.remove(queryParam);
          } else {
            p[queryParam] = query;
          }
          ctx.reload(p);
        },
      ),
    );
  }

  // ── chipGroup ─────────────────────────────────────────────────────────────

  static Widget _buildChipGroup(SduiContext ctx, Map<String, dynamic> node) {
    final chips = (node['chips'] as List<dynamic>?) ?? [];
    final style = node['style'] as Map<String, dynamic>?;
    final padding =
        _resolvePadding(style?['padding']) ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    final onSelect = node['onSelect'] as Map<String, dynamic>?;
    final qParam = onSelect?['queryParam'] as String? ?? 'filter';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: chips.map((raw) {
          final chip = raw as Map<String, dynamic>;
          final label = chip['label'] as String? ?? '';
          final value = chip['value'] as String? ?? '';
          final selected = chip['selected'] as bool? ?? false;
          final chipColor = chip['color'] != null
              ? _hexColor(chip['color'] as String)
              : const Color(0xFF6366F1);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (onSelect == null) return;
                final p = Map<String, String>.from(ctx.currentParams);
                if (value == 'all') {
                  p.remove(qParam);
                } else {
                  p[qParam] = value;
                }
                ctx.reload(p);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? chipColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? chipColor : Colors.grey.shade300,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: chipColor.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey.shade700,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── emptyState ────────────────────────────────────────────────────────────

  static Widget _buildEmptyState(Map<String, dynamic> node) {
    final icon = _resolveIcon(node['icon'] as String? ?? 'inbox');
    final title = node['title'] as String? ?? 'No items';
    final subtitle = node['subtitle'] as String?;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── orderCounter ──────────────────────────────────────────────────────────

  static Widget _buildOrderCounter(
    SduiContext ctx,
    Map<String, dynamic> node,
    Map<String, dynamic> data,
  ) {
    final customerId = _resolve(node['customerId'] as String? ?? '', data);
    final initialCount =
        int.tryParse(_resolve(node['value'] as String? ?? '0', data)) ?? 0;
    final min = node['min'] as int? ?? 0;
    final label = node['label'] as String? ?? 'Orders';
    final style = node['style'] as Map<String, dynamic>?;

    final activeColor = style?['activeColor'] != null
        ? _hexColor(style!['activeColor'] as String)
        : const Color(0xFF6366F1);
    final trackColor = style?['trackColor'] != null
        ? _hexColor(style!['trackColor'] as String)
        : const Color(0xFFEEF2FF);
    final textColor = style?['textColor'] != null
        ? _hexColor(style!['textColor'] as String)
        : const Color(0xFF1A1A2E);
    final labelColor = style?['labelColor'] != null
        ? _hexColor(style!['labelColor'] as String)
        : const Color(0xFF6B7280);

    return _OrderCounterWidget(
      customerId: customerId,
      initialCount: initialCount,
      min: min,
      label: label,
      activeColor: activeColor,
      trackColor: trackColor,
      textColor: textColor,
      labelColor: labelColor,
      onChanged: (newCount) =>
          ctx.onUpdateOrders(customerId, newCount.toString()),
    );
  }

  // ─── Action handler ───────────────────────────────────────────────────────

  static void _handleAction(
    SduiContext ctx,
    Map<String, dynamic>? action,
    Map<String, dynamic> data,
  ) {
    if (action == null) return;
    switch (action['type'] as String? ?? '') {
      case 'navigate':
        final route = action['route'] as String?;
        if (route == null) return;
        final rawParams = action['params'] as Map<String, dynamic>?;
        final resolved = rawParams?.map(
          (k, v) => MapEntry(k, _resolve(v, data)),
        );
        Navigator.pushNamed(ctx.buildContext, route, arguments: resolved);

      case 'toggleVisibility':
        final target = action['target'] as String?;
        if (target != null) ctx.toggleVisibility(target);

      case 'reload':
        final param = action['queryParam'] as String?;
        final value = action['value'] as String?;
        if (param != null && value != null) {
          final p = Map<String, String>.from(ctx.currentParams);
          p[param] = value;
          ctx.reload(p);
        }

      default:
        debugPrint('[SDUI] Unknown action: ${action['type']}');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Resolves "{key}" and "{a.b}" placeholders from [data].
  static String _resolve(dynamic raw, Map<String, dynamic> data) {
    if (raw == null) return '';
    return raw.toString().replaceAllMapped(RegExp(r'\{(.*?)\}'), (m) {
      final keys = (m.group(1) ?? '').split('.');
      dynamic val = data;
      for (final key in keys) {
        if (val is Map && val.containsKey(key)) {
          val = val[key];
        } else {
          return m.group(0)!; // keep original if not found
        }
      }
      return val?.toString() ?? '';
    });
  }

  static EdgeInsets? _resolvePadding(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return EdgeInsets.all(raw.toDouble());
    if (raw is! Map) return null;
    final all = (raw['all'] as num?)?.toDouble();
    if (all != null) return EdgeInsets.all(all);
    final h = ((raw['horizontal'] ?? 0) as num).toDouble();
    final v = ((raw['vertical'] ?? 0) as num).toDouble();
    final l = ((raw['left'] ?? h) as num).toDouble();
    final r = ((raw['right'] ?? h) as num).toDouble();
    final t = ((raw['top'] ?? v) as num).toDouble();
    final b = ((raw['bottom'] ?? v) as num).toDouble();
    return EdgeInsets.fromLTRB(l, t, r, b);
  }

  static BoxShadow _resolveBoxShadow(Map<String, dynamic> s) {
    return BoxShadow(
      color: s['color'] != null
          ? _hexColor(s['color'] as String)
          : Colors.black.withOpacity(0.1),
      blurRadius: (s['blur'] as num?)?.toDouble() ?? 8,
      offset: Offset(
        (s['offsetX'] as num?)?.toDouble() ?? 0,
        (s['offsetY'] as num?)?.toDouble() ?? 2,
      ),
    );
  }

  static CrossAxisAlignment _resolveCrossAxis(String? v) {
    switch (v) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      default:
        return CrossAxisAlignment.center;
    }
  }

  static FontWeight _resolveFontWeight(String? v) {
    switch (v) {
      case 'bold':
        return FontWeight.bold;
      case 'semibold':
        return FontWeight.w600;
      case 'medium':
        return FontWeight.w500;
      case 'light':
        return FontWeight.w300;
      default:
        return FontWeight.normal;
    }
  }

  static IconData _resolveIcon(String name) {
    const map = {
      'search': Icons.search_rounded,
      'filter_list': Icons.filter_list_rounded,
      'add': Icons.add_rounded,
      'person_add': Icons.person_add_rounded,
      'person_off': Icons.person_off_rounded,
      'person_search': Icons.person_search_rounded,
      'cloud_off': Icons.cloud_off_rounded,
      'inbox': Icons.inbox_rounded,
      'refresh': Icons.refresh_rounded,
      'more_vert': Icons.more_vert_rounded,
      'close': Icons.close_rounded,
      'check': Icons.check_rounded,
      'arrow_back': Icons.arrow_back_ios_new_rounded,
    };
    return map[name] ?? Icons.widgets_rounded;
  }

  /// Parses #RRGGBB or #AARRGGBB hex strings.
  static Color _hexColor(String hex) {
    final cleaned = hex.replaceAll('#', '').trim();
    final value =
        int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16) ??
        0xFF6366F1;
    return Color(value);
  }
}

// ─── Order counter stateful widget ────────────────────────────────────────────

class _OrderCounterWidget extends StatefulWidget {
  final String customerId;
  final int initialCount;
  final int min;
  final String label;
  final Color activeColor;
  final Color trackColor;
  final Color textColor;
  final Color labelColor;
  final void Function(int newCount) onChanged;

  const _OrderCounterWidget({
    required this.customerId,
    required this.initialCount,
    required this.min,
    required this.label,
    required this.activeColor,
    required this.trackColor,
    required this.textColor,
    required this.labelColor,
    required this.onChanged,
  });

  @override
  State<_OrderCounterWidget> createState() => _OrderCounterWidgetState();
}

class _OrderCounterWidgetState extends State<_OrderCounterWidget> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
  }

  @override
  void didUpdateWidget(covariant _OrderCounterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCount != widget.initialCount) {
      _count = widget.initialCount;
    }
  }

  void _update(int delta) {
    final newValue = _count + delta;
    if (newValue < widget.min) return;
    setState(() => _count = newValue);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: widget.labelColor,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: widget.trackColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBtn(Icons.remove, () => _update(-1)),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                child: Text(
                  '$_count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                  ),
                ),
              ),
              _buildBtn(Icons.add, () => _update(1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: widget.activeColor),
        ),
      ),
    );
  }
}
