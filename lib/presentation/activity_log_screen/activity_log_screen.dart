import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/activity_log_service.dart';
import '../../services/permission_service.dart';
import '../../services/realtime_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/empty_state_widget.dart';
import './widgets/activity_log_chart_widget.dart';
import './widgets/activity_log_filter_widget.dart';
import './widgets/activity_log_list_widget.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String _userRole = 'Owner';
  String _userName = '';
  String _userId = '';
  String _storeId = '';
  String _storeName = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  bool _didInit = false;
  bool _realtimeSubscribed = false;

  // All loaded entries (accumulated across pages)
  List<ActivityLogEntry> _logs = [];

  // Filters
  String _filterUser = '';
  String _filterItem = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _filterActionGroup = 'All'; // All, Stock, Items, Users

  @override
  void initState() {
    super.initState();
    // Do NOT call _loadFirstPage here — _storeId is not yet set.
    // Loading is triggered from didChangeDependencies once args are available.
  }

  @override
  void dispose() {
    RealtimeService.instance.unsubscribe('activity_logs_$_storeId');
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final role = args['role'] as String? ?? 'Owner';
      _userName = args['userName'] as String? ?? '';
      _userId = args['userId'] as String? ?? '';
      final newStoreId = args['storeId'] as String? ?? '';
      _storeName = args['storeName'] as String? ?? '';
      final isActive = args['isActive'] as bool? ?? true;
      PermissionService.instance.setUser(
        role: role,
        userId: _userId,
        isActive: isActive,
      );
      // Reload if role or store changed, or on first init
      if (role != _userRole || newStoreId != _storeId || !_didInit) {
        _userRole = role;
        _storeId = newStoreId;
        _didInit = true;
        _loadFirstPage();
      }
    } else if (!_didInit) {
      _didInit = true;
    }
  }

  /// Returns allowed action types based on role and current group filter
  List<String>? _getActionTypesForQuery() {
    // Role restriction
    List<String>? roleTypes;
    if (_userRole == 'Manager') {
      roleTypes = [ActivityActionType.stockIn, ActivityActionType.stockOut];
    }

    // Group filter restriction
    List<String>? groupTypes;
    if (_filterActionGroup == 'Stock') {
      groupTypes = [ActivityActionType.stockIn, ActivityActionType.stockOut];
    } else if (_filterActionGroup == 'Items') {
      groupTypes = [
        ActivityActionType.itemCreated,
        ActivityActionType.itemEdited,
        ActivityActionType.itemDeleted,
      ];
    } else if (_filterActionGroup == 'Users') {
      groupTypes = [
        ActivityActionType.userAdded,
        ActivityActionType.userRemoved,
        ActivityActionType.roleChanged,
        ActivityActionType.userEnabled,
        ActivityActionType.userDisabled,
      ];
    }

    // Intersect role and group constraints
    if (roleTypes != null && groupTypes != null) {
      final intersection = roleTypes
          .where((t) => groupTypes!.contains(t))
          .toList();
      return intersection.isEmpty ? ['__none__'] : intersection;
    }
    return roleTypes ?? groupTypes;
  }

  Future<void> _loadFirstPage() async {
    if (!mounted) return;
    // Unsubscribe existing realtime channel before re-subscribing
    if (_realtimeSubscribed) {
      RealtimeService.instance.unsubscribe('activity_logs_$_storeId');
      _realtimeSubscribed = false;
    }
    setState(() {
      _isLoading = true;
      _logs = [];
      _currentPage = 0;
      _hasMore = true;
    });
    await _fetchPage(0, isFirst: true);
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    if (_realtimeSubscribed || _storeId.isEmpty) return;
    _realtimeSubscribed = true;

    RealtimeService.instance.subscribeToTable(
      channelName: 'activity_logs_$_storeId',
      table: 'activity_logs',
      storeId: _storeId,
      onInsert: (record) {
        if (!mounted) return;
        // Only prepend if no active filters (so the new entry is visible)
        final noFilters =
            _filterUser.isEmpty &&
            _filterItem.isEmpty &&
            _fromDate == null &&
            _toDate == null &&
            _filterActionGroup == 'All';
        if (noFilters) {
          final newEntry = ActivityLogEntry.fromMap(record);
          setState(() {
            if (!_logs.any((l) => l.id == newEntry.id)) {
              _logs.insert(0, newEntry);
            }
          });
        }
      },
    );
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _fetchPage(_currentPage + 1, isFirst: false);
  }

  Future<void> _fetchPage(int page, {required bool isFirst}) async {
    try {
      final result = await ActivityLogService.instance.fetchLogsPage(
        storeId: _storeId,
        filterUser: _filterUser.isEmpty ? null : _filterUser,
        filterItem: _filterItem.isEmpty ? null : _filterItem,
        fromDate: _fromDate,
        toDate: _toDate,
        actionTypes: _getActionTypesForQuery(),
        page: page,
      );
      if (mounted) {
        setState(() {
          if (isFirst) {
            _logs = result.logs;
          } else {
            _logs = [..._logs, ...result.logs];
          }
          _hasMore = result.hasMore;
          _currentPage = page;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        filterUser: _filterUser,
        filterItem: _filterItem,
        fromDate: _fromDate,
        toDate: _toDate,
        onApply: (user, item, from, to) {
          setState(() {
            _filterUser = user;
            _filterItem = item;
            _fromDate = from;
            _toDate = to;
          });
          _loadFirstPage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    int navIndex = 2;
    if (_userRole == 'Manager') navIndex = 2;
    if (_userRole == 'Owner') navIndex = 2;

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: AppNavigation(
        currentIndex: navIndex,
        userRole: _userRole,
        userName: _userName,
        userId: _userId,
        isActive: PermissionService.instance.isActive,
        storeId: _storeId,
        storeName: _storeName,
      ),
      body: isTablet
          ? Row(
              children: [
                AppNavigation(
                  currentIndex: navIndex,
                  userRole: _userRole,
                  userName: _userName,
                  userId: _userId,
                  isActive: PermissionService.instance.isActive,
                  storeId: _storeId,
                  storeName: _storeName,
                ),
                Expanded(child: _buildBody()),
              ],
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final stockLogs = _logs
        .where((l) => ActivityActionType.isStockAction(l.actionType))
        .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (!_isLoading && stockLogs.isNotEmpty) ...[
            ActivityLogChartWidget(logs: stockLogs),
            const SizedBox(height: 8),
          ],
          // Action group filter tabs (Owner only)
          if (_userRole == 'Owner') ...[
            _buildActionGroupFilter(),
            const SizedBox(height: 8),
          ],
          // Stock filter (In/Out counts)
          ActivityLogFilterWidget(
            selected:
                _filterActionGroup == 'Stock' || _filterActionGroup == 'All'
                ? 'All'
                : 'All',
            onChanged: (_) {},
            inCount: _logs
                .where((l) => l.actionType == ActivityActionType.stockIn)
                .length,
            outCount: _logs
                .where((l) => l.actionType == ActivityActionType.stockOut)
                .length,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _logs.isEmpty && !_isLoading
                ? EmptyStateWidget(
                    icon: Icons.history_rounded,
                    title: 'No activity yet',
                    subtitle: _userRole == 'Manager'
                        ? 'Stock in/out transactions will appear here.'
                        : 'All actions will appear here once recorded.',
                  )
                : ActivityLogListWidget(
                    logs: _logs,
                    isLoading: _isLoading,
                    isLoadingMore: _isLoadingMore,
                    hasMore: _hasMore,
                    onLoadMore: _loadNextPage,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final hasActiveFilters =
        _filterUser.isNotEmpty ||
        _filterItem.isNotEmpty ||
        _fromDate != null ||
        _toDate != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Log',
                  style: GoogleFonts.fraunces(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${_logs.length}${_hasMore ? '+' : ''} entries · ${_userRole == 'Manager' ? 'Stock actions only' : 'All actions'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadFirstPage,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: AppTheme.onSurfaceMuted,
            ),
            tooltip: 'Refresh',
          ),
          Stack(
            children: [
              IconButton(
                onPressed: _showFilterSheet,
                icon: const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: AppTheme.onSurface,
                ),
                tooltip: 'Filter',
              ),
              if (hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGroupFilter() {
    final groups = ['All', 'Stock', 'Items', 'Users'];
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groups.length,
        itemBuilder: (_, i) {
          final g = groups[i];
          final isSelected = _filterActionGroup == g;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _filterActionGroup = g);
                _loadFirstPage();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.outline,
                  ),
                ),
                child: Text(
                  g,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? const Color(0xFF111113)
                        : AppTheme.onSurfaceSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Filter bottom sheet
class _FilterSheet extends StatefulWidget {
  final String filterUser;
  final String filterItem;
  final DateTime? fromDate;
  final DateTime? toDate;
  final Function(String user, String item, DateTime? from, DateTime? to)
  onApply;

  const _FilterSheet({
    required this.filterUser,
    required this.filterItem,
    required this.fromDate,
    required this.toDate,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TextEditingController _userController;
  late TextEditingController _itemController;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _userController = TextEditingController(text: widget.filterUser);
    _itemController = TextEditingController(text: widget.filterItem);
    _fromDate = widget.fromDate;
    _toDate = widget.toDate;
  }

  @override
  void dispose() {
    _userController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Select date';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Filter Logs',
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _userController,
            decoration: InputDecoration(
              labelText: 'Filter by User',
              hintText: 'e.g. Priya Sharma',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              suffixIcon: _userController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _userController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _itemController,
            decoration: InputDecoration(
              labelText: 'Filter by Item',
              hintText: 'e.g. Wireless Keyboard',
              prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
              suffixIcon: _itemController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _itemController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text(
            'DATE RANGE',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.outline),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppTheme.onSurfaceMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _fromDate == null ? 'From' : _formatDate(_fromDate),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: _fromDate == null
                                ? AppTheme.onSurfaceMuted
                                : AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: AppTheme.onSurfaceMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.outline),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppTheme.onSurfaceMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _toDate == null ? 'To' : _formatDate(_toDate),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: _toDate == null
                                ? AppTheme.onSurfaceMuted
                                : AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _userController.clear();
                    _itemController.clear();
                    setState(() {
                      _fromDate = null;
                      _toDate = null;
                    });
                    widget.onApply('', '', null, null);
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _userController.text.trim(),
                      _itemController.text.trim(),
                      _fromDate,
                      _toDate,
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
