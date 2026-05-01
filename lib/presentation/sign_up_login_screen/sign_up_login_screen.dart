import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import './widgets/auth_form_widget.dart';

class SignUpLoginScreen extends StatefulWidget {
  const SignUpLoginScreen({super.key});

  @override
  State<SignUpLoginScreen> createState() => _SignUpLoginScreenState();
}

class _SignUpLoginScreenState extends State<SignUpLoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
        );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    _fadeController.reset();
    setState(() => _isLogin = !_isLogin);
    _fadeController.forward();
  }

  void _onAuthSuccess(String role, String userName, String userId) {
    // Navigation is now handled inside AuthFormWidget after store check
    // This callback is kept for API compatibility but not used for navigation
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Layered background
          _BackgroundLayer(),
          SafeArea(
            child: isTablet ? _buildTabletLayout() : _buildPhoneLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),
              _BrandHeader(),
              const SizedBox(height: 44),
              _FormCard(
                isLogin: _isLogin,
                onToggle: _toggleMode,
                onSuccess: _onAuthSuccess,
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  _BrandHeader(),
                  const SizedBox(height: 40),
                  _FormCard(
                    isLogin: _isLogin,
                    onToggle: _toggleMode,
                    onSuccess: _onAuthSuccess,
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox.expand(
      child: CustomPaint(
        painter: _BgPainter(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111113), Color(0xFF161410), Color(0xFF111113)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withAlpha(18)
      ..style = PaintingStyle.fill;

    // Large ambient circle top-right
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.12),
      size.width * 0.55,
      paint,
    );

    // Smaller accent bottom-left
    final paint2 = Paint()
      ..color = AppTheme.secondary.withAlpha(12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.85),
      size.width * 0.4,
      paint2,
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = AppTheme.outline.withAlpha(25)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo mark
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFF111113),
            size: 26,
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Stock',
                style: GoogleFonts.fraunces(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              TextSpan(
                text: 'Track',
                style: GoogleFonts.fraunces(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Inventory intelligence\nfor modern teams.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppTheme.onSurfaceSecondary,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;
  final Function(String, String, String) onSuccess;

  const _FormCard({
    required this.isLogin,
    required this.onToggle,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AuthFormWidget(
        isLogin: isLogin,
        onToggle: onToggle,
        onSuccess: onSuccess,
      ),
    );
  }
}
