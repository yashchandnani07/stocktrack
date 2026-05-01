import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../services/stock_session_service.dart';

/// Screen showing history of past stock sessions
class StockSessionHistoryScreen extends StatefulWidget {
  const StockSessionHistoryScreen({super.key});

  @override
  State<StockSessionHistoryScreen> createState() =>
      _StockSessionHistoryScreenState();
}

class _StockSessionHistoryScreenState extends State<StockSessionHistoryScreen> {
  late String _storeId;
  late String _storeName;
  List<StockSession> _sessions = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  bool _didInit = false;
  static const int _pageSize = 20;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
    _storeId = args['storeId'] as String? ?? '';
    _storeName = args['storeName'] as String? ?? '';
    if (!_didInit) {
      _didInit = true;
      _loadSessions();
    }
  }

  Future<void> _loadSessions({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _sessions = [];
        _offset = 0;
        _hasMore = true;
        _isLoading = true;
      });
    }

    final results = await StockSessionService.instance.fetchSessions(
      storeId: _storeId,
      limit: _pageSize,
      offset: _offset,
    );

    if (mounted) {
      setState(() {
        _sessions.addAll(results);
        _offset += results.length;
        _hasMore = results.length == _pageSize;
        _isLoading = false;
      });
    }
  }

  Future<void> _viewSession(StockSession session) async {
    final full = await StockSessionService.instance.fetchSessionWithItems(
      session.id,
    );
    if (!mounted || full == null) return;

    Navigator.pushNamed(
      context,
      '/stock-session-success',
      arguments: {
        'session': full,
        'storeName': _storeName,
        'failedItems': <String>[],
      },
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session History',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              _storeName,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: AppTheme.onSurfaceMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No sessions yet',
                    style: GoogleFonts.fraunces(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock sessions will appear here',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () => _loadSessions(refresh: true),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _sessions.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _sessions.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: TextButton(
                          onPressed: _loadSessions,
                          child: Text(
                            'Load More',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return _buildSessionCard(_sessions[i]);
                },
              ),
            ),
    );
  }

  Widget _buildSessionCard(StockSession session) {
    final isStockIn = session.sessionType == 'IN';
    final accentColor = isStockIn ? AppTheme.secondary : AppTheme.error;
    final accentBg = isStockIn ? AppTheme.secondaryLight : AppTheme.errorLight;

    return GestureDetector(
      onTap: () => _viewSession(session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isStockIn
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isStockIn ? 'Stock In' : 'Stock Out',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${session.totalItems} items',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${session.performedByName} · ${_formatDate(session.createdAt)} ${_formatTime(session.createdAt)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.onSurfaceMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.onSurfaceMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
