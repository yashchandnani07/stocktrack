import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static const String _dartDefineUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _dartDefineAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// The URL that was actually used to initialize Supabase (set after init).
  static String _resolvedUrl = '';
  static String get resolvedUrl => _resolvedUrl;

  /// Loads Supabase credentials: prefers dart-define values (web preview),
  /// falls back to env.json bundled in assets (APK builds without dart-define).
  static Future<Map<String, String>> _loadCredentials() async {
    if (_dartDefineUrl.isNotEmpty && _dartDefineAnonKey.isNotEmpty) {
      debugPrint(
        '[SupabaseService] Credentials source: dart-define '
        '(URL domain: ${_extractDomain(_dartDefineUrl)})',
      );
      return {'url': _dartDefineUrl, 'anonKey': _dartDefineAnonKey};
    }

    debugPrint(
      '[SupabaseService] dart-define values empty — falling back to env.json',
    );

    // Fallback: read from bundled env.json
    try {
      final jsonStr = await rootBundle.loadString('env.json');
      final Map<String, dynamic> env = json.decode(jsonStr);
      final url = env['SUPABASE_URL'] as String? ?? '';
      final anonKey = env['SUPABASE_ANON_KEY'] as String? ?? '';
      if (url.isNotEmpty && anonKey.isNotEmpty) {
        debugPrint(
          '[SupabaseService] Credentials source: env.json '
          '(URL domain: ${_extractDomain(url)})',
        );
        return {'url': url, 'anonKey': anonKey};
      }
      debugPrint(
        '[SupabaseService] env.json loaded but SUPABASE_URL or '
        'SUPABASE_ANON_KEY is empty!',
      );
    } catch (e) {
      debugPrint('[SupabaseService] Failed to load env.json: $e');
    }

    throw Exception(
      'SUPABASE_URL and SUPABASE_ANON_KEY are not configured. '
      'Provide them via --dart-define or env.json.',
    );
  }

  /// Extracts just the hostname from a URL for safe logging (no keys exposed).
  static String _extractDomain(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return '(unparseable)';
    }
  }

  // Initialize Supabase - call this in main()
  static Future<void> initialize() async {
    debugPrint('[SupabaseService] Initializing...');
    final creds = await _loadCredentials();
    _resolvedUrl = creds['url']!;
    await Supabase.initialize(url: creds['url']!, anonKey: creds['anonKey']!);
    debugPrint(
      '[SupabaseService] Initialized successfully. '
      'URL domain: ${_extractDomain(_resolvedUrl)}',
    );

    // Log current auth state immediately after init
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      debugPrint(
        '[SupabaseService] Existing session found — user_id: ${user.id} '
        'email: ${user.email}',
      );
    } else {
      debugPrint('[SupabaseService] No existing session (user not signed in).');
    }
  }

  // Get Supabase client
  SupabaseClient get client => Supabase.instance.client;
}
