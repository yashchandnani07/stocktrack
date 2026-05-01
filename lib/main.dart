import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_export.dart';
import '../widgets/custom_error_widget.dart';
import './services/permission_service.dart';
import './services/store_service.dart';
import './services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('[main] Failed to initialize Supabase: $e');
  }

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      // Reset flag after 3 seconds to allow error widget on new screens
      Future.delayed(Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }
    return SizedBox.shrink();
  };

  // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
  Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ]).then((value) {
    runApp(MyApp());
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _initialRoute = AppRoutes.signUpLoginScreen;
  Map<String, dynamic>? _initialArgs;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  /// On APK, Supabase restores the session from local storage during
  /// initialize(). We check here if a valid session exists and, if so,
  /// fetch the user's stores and navigate directly to inventory — skipping
  /// the login screen. This is the root cause of "data not visible on APK":
  /// the user was forced to re-login but the store context was never set.
  Future<void> _resolveInitialRoute() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      debugPrint(
        '[main] _resolveInitialRoute — '
        'platform: ${kIsWeb ? "web" : "mobile"} '
        'user_id: ${user?.id ?? "null"} '
        'email: ${user?.email ?? "null"}',
      );

      if (user != null) {
        final userName =
            user.userMetadata?['full_name'] as String? ??
            user.email?.split('@').first ??
            'User';
        final userId = user.id;

        debugPrint(
          '[main] Existing session — '
          'platform: ${kIsWeb ? "web" : "mobile"} '
          'user_id: $userId email: ${user.email} — '
          'clearing stale singleton + fetching stores...',
        );

        // FORCE STORE FETCH AFTER LOGIN/RESTORE — clear any stale singleton
        // state (e.g. from a previous account on the same device) before
        // re-resolving. Web and mobile run identical code here.
        final result =
            await StoreService.instance.resolveCurrentStoreAfterLogin();
        final stores = result.stores;

        debugPrint(
          '[main] Stores found: ${stores.length} '
          '${stores.map((s) => '${s.name}(${s.id})').join(', ')} '
          'autoSelected: ${result.autoSelected?.id ?? "null"}',
        );

        if (stores.isEmpty) {
          setState(() {
            _initialRoute = AppRoutes.createStoreScreen;
            _initialArgs = {'userName': userName, 'userId': userId};
            _ready = true;
          });
          return;
        }

        if (result.autoSelected != null) {
          final store = result.autoSelected!;
          final role = result.role;
          // resolveCurrentStoreAfterLogin already wrote into StoreService;
          // assert here so any future regression is loud.
          assert(StoreService.instance.currentStore?.id == store.id);

          // Check is_active for members (owners are always active)
          bool isActive = true;
          try {
            final resp = await client
                .from('store_members')
                .select('is_active')
                .eq('store_id', store.id)
                .eq('user_id', userId)
                .maybeSingle();
            if (resp != null) {
              isActive = resp['is_active'] as bool? ?? true;
            }
          } catch (_) {}

          // CRITICAL: initialize PermissionService BEFORE navigating
          PermissionService.instance.setUser(
            role: role,
            userId: userId,
            isActive: isActive,
            storeId: store.id,
          );

          debugPrint(
            '[main] Auto-navigating to inventory — '
            'platform: ${kIsWeb ? "web" : "mobile"} '
            'user_id: $userId '
            'store_id: ${store.id} '
            'store_name: "${store.name}" '
            'role: $role isActive: $isActive',
          );

          if (!isActive) {
            // Disabled user — clear store and send to login
            StoreService.instance.clearCurrentStore();
            setState(() {
              _initialRoute = AppRoutes.signUpLoginScreen;
              _ready = true;
            });
            return;
          }

          setState(() {
            _initialRoute = AppRoutes.inventoryScreen;
            _initialArgs = {
              'role': role,
              'userName': userName,
              'userId': userId,
              'isActive': isActive,
              'storeId': store.id,
              'storeName': store.name,
            };
            _ready = true;
          });
          return;
        }

        // Multiple stores — show store selector. StoreService is already
        // cleared by resolveCurrentStoreAfterLogin, so no stale fallback.
        setState(() {
          _initialRoute = AppRoutes.selectStoreScreen;
          _initialArgs = {'userName': userName, 'userId': userId};
          _ready = true;
        });
        return;
      }
    } catch (e) {
      debugPrint('[main] _resolveInitialRoute error: $e');
    }

    // No session or error — go to login
    setState(() {
      _initialRoute = AppRoutes.signUpLoginScreen;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Show a minimal splash while resolving the session
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          backgroundColor: Color(0xFF111113),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFE8FF47)),
          ),
        ),
      );
    }

    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: 'stocktrack',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.0)),
              child: child!,
            );
          },
          // 🚨 END CRITICAL SECTION
          debugShowCheckedModeBanner: false,
          routes: AppRoutes.routes,
          initialRoute: _initialRoute,
          onGenerateInitialRoutes: _initialArgs != null
              ? (route) => [
                  MaterialPageRoute(
                    builder: AppRoutes.routes[_initialRoute]!,
                    settings: RouteSettings(
                      name: _initialRoute,
                      arguments: _initialArgs,
                    ),
                  ),
                ]
              : null,
        );
      },
    );
  }
}
