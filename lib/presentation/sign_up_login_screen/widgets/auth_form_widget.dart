import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../services/store_service.dart';
import '../../../services/permission_service.dart';
import '../../../routes/app_routes.dart';

class AuthFormWidget extends StatefulWidget {
  final bool isLogin;
  final VoidCallback onToggle;
  final Function(String role, String userName, String userId) onSuccess;

  const AuthFormWidget({
    super.key,
    required this.isLogin,
    required this.onToggle,
    required this.onSuccess,
  });

  @override
  State<AuthFormWidget> createState() => _AuthFormWidgetState();
}

class _AuthFormWidgetState extends State<AuthFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (widget.isLogin) {
        await _handleLogin();
      } else {
        await _handleSignUp();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = 'An unexpected error occurred. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    final response = await _client.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final user = response.user;
    if (user == null) {
      setState(
        () => _errorMessage = 'Login failed. Please check your credentials.',
      );
      return;
    }

    debugPrint(
      '[AuthForm] Login success — user_id: ${user.id} email: ${user.email}',
    );

    final userName =
        user.userMetadata?['full_name'] as String? ??
        user.email?.split('@').first ??
        'User';

    await _navigateAfterAuth(userId: user.id, userName: userName);
  }

  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final response = await _client.auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      data: {'full_name': name},
    );

    final user = response.user;
    if (user == null) {
      setState(() => _errorMessage = 'Sign up failed. Please try again.');
      return;
    }

    debugPrint(
      '[AuthForm] Sign-up success — user_id: ${user.id} email: ${user.email}',
    );

    await _navigateAfterAuth(userId: user.id, userName: name);
  }

  Future<void> _navigateAfterAuth({
    required String userId,
    required String userName,
  }) async {
    if (!mounted) return;

    debugPrint('[AuthForm] _navigateAfterAuth — user_id: $userId');

    // Fetch stores for this user
    final stores = await StoreService.instance.fetchMyStores();

    debugPrint(
      '[AuthForm] _navigateAfterAuth — stores found: ${stores.length}',
    );

    if (!mounted) return;

    if (stores.isEmpty) {
      // New user — prompt to create first store
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.createStoreScreen,
        arguments: {'userName': userName, 'userId': userId},
      );
    } else if (stores.length == 1) {
      // Single store — go directly
      final store = stores.first;
      final role = await StoreService.instance.getRoleInStore(store.id);
      StoreService.instance.setCurrentStore(store, role);

      debugPrint(
        '[AuthForm] Single store selected — store_id: ${store.id} '
        'name: "${store.name}" role: $role',
      );

      // Fetch actual is_active status for this member
      bool isActive = true;
      try {
        final resp = await _client
            .from('store_members')
            .select('is_active')
            .eq('store_id', store.id)
            .eq('user_id', userId)
            .maybeSingle();
        if (resp != null) {
          isActive = resp['is_active'] as bool? ?? true;
        }
      } catch (_) {
        // Owner won't have a store_members row — default to active
      }

      PermissionService.instance.setUser(
        role: role,
        userId: userId,
        isActive: isActive,
        storeId: store.id,
      );

      if (!mounted) return;

      if (!isActive) {
        setState(
          () => _errorMessage =
              'Your account has been disabled. Contact the store owner.',
        );
        return;
      }

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.inventoryScreen,
        arguments: {
          'role': role,
          'userName': userName,
          'userId': userId,
          'isActive': isActive,
          'storeId': store.id,
          'storeName': store.name,
        },
      );
    } else {
      // Multiple stores — show selector
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.selectStoreScreen,
        arguments: {'userName': userName, 'userId': userId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isLogin ? 'Welcome back' : 'Create account',
                      style: GoogleFonts.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isLogin
                          ? 'Sign in to your workspace'
                          : 'Join StockTrack',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!widget.isLogin) ...[
            _buildField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Your full name',
              icon: Icons.person_outline_rounded,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                return null;
              },
            ),
            const SizedBox(height: 14),
          ],
          _buildField(
            controller: _emailController,
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildPasswordField(),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withAlpha(60)),
              ),
              child: Text(
                _errorMessage,
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.error),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildSubmitButton(),
          const SizedBox(height: 16),
          _buildToggleLink(),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.onSurfaceMuted),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password is required';
        if (v.length < 6) return 'Minimum 6 characters';
        return null;
      },
      style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.onSurface),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: '••••••••',
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: AppTheme.onSurfaceMuted,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: AppTheme.onSurfaceMuted,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: const Color(0xFF111113),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        disabledBackgroundColor: AppTheme.primary.withAlpha(80),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF111113),
              ),
            )
          : Text(
              widget.isLogin ? 'Sign In' : 'Create Account',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }

  Widget _buildToggleLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.isLogin
              ? "Don't have an account? "
              : 'Already have an account? ',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        GestureDetector(
          onTap: widget.onToggle,
          child: Text(
            widget.isLogin ? 'Sign up' : 'Sign in',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
