import 'package:supabase_flutter/supabase_flutter.dart';
import './supabase_service.dart';

/// Manages Supabase real-time channel subscriptions for a store.
/// Each screen subscribes to the relevant table and provides a callback
/// that is invoked whenever a row is inserted, updated, or deleted.
class RealtimeService {
  static RealtimeService? _instance;
  static RealtimeService get instance => _instance ??= RealtimeService._();
  RealtimeService._();

  SupabaseClient get _client => SupabaseService.instance.client;

  // Active channels keyed by a unique channel name
  final Map<String, RealtimeChannel> _channels = {};

  /// Subscribe to changes on [table] filtered by store_id == [storeId].
  /// [channelName] must be unique per subscription (e.g. 'inventory_<storeId>').
  /// [onInsert], [onUpdate], [onDelete] are called with the new/old record map.
  RealtimeChannel subscribeToTable({
    required String channelName,
    required String table,
    required String storeId,
    void Function(Map<String, dynamic> record)? onInsert,
    void Function(Map<String, dynamic> record)? onUpdate,
    void Function(Map<String, dynamic> record)? onDelete,
  }) {
    // Guard: never subscribe with an empty storeId — it would match all rows
    if (storeId.isEmpty) {
      // Return a no-op channel by re-using any existing or creating a dummy
      // that is immediately unsubscribed
      final dummy = _client.channel('noop_$channelName');
      return dummy;
    }

    // Remove any existing channel with the same name first
    unsubscribe(channelName);

    final channel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            if (onInsert != null) onInsert(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            if (onUpdate != null) onUpdate(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            if (onDelete != null) onDelete(payload.oldRecord);
          },
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  /// Unsubscribe and remove a channel by name.
  void unsubscribe(String channelName) {
    final ch = _channels.remove(channelName);
    ch?.unsubscribe();
  }

  /// Unsubscribe all channels (call on store switch / logout).
  void unsubscribeAll() {
    for (final ch in _channels.values) {
      ch.unsubscribe();
    }
    _channels.clear();
  }
}
