import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingSkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<LoadingSkeletonWidget> createState() => _LoadingSkeletonWidgetState();
}

class _LoadingSkeletonWidgetState extends State<LoadingSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _shimmerAnimation = Tween<double>(
      begin: -0.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                _shimmerAnimation.value.clamp(0.0, 1.0),
                (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: const [
                AppTheme.outline,
                AppTheme.surfaceElevated,
                AppTheme.outline,
              ],
            ),
          ),
        );
      },
    );
  }
}

class InventoryItemSkeleton extends StatelessWidget {
  const InventoryItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LoadingSkeletonWidget(
                width: 40,
                height: 40,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeletonWidget(
                      width: MediaQuery.of(context).size.width * 0.4,
                      height: 14,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 6),
                    LoadingSkeletonWidget(
                      width: MediaQuery.of(context).size.width * 0.25,
                      height: 11,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ),
              const LoadingSkeletonWidget(
                width: 48,
                height: 24,
                borderRadius: 6,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const LoadingSkeletonWidget(
                width: 72,
                height: 32,
                borderRadius: 8,
              ),
              const SizedBox(width: 8),
              const LoadingSkeletonWidget(
                width: 72,
                height: 32,
                borderRadius: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
