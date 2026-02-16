import 'package:flutter/material.dart';

/// Shimmer effect widget — no external packages needed.
/// Uses AnimationController + LinearGradient + ShaderMask.
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Full-page skeleton matching the 5-section dashboard layout.
class DashboardShimmer extends StatefulWidget {
  const DashboardShimmer({super.key});

  @override
  State<DashboardShimmer> createState() => _DashboardShimmerState();
}

class _DashboardShimmerState extends State<DashboardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child!,
        );
      },
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),

            // Section 1: Today Summary skeleton
            const ShimmerBox(width: 180, height: 24, borderRadius: 8),
            const SizedBox(height: 8),
            const ShimmerBox(width: 120, height: 18, borderRadius: 8),
            const SizedBox(height: 16),
            const ShimmerBox(
              width: double.infinity,
              height: 140,
              borderRadius: 16,
            ),
            const SizedBox(height: 24),

            // Section 2: Key Signals 2x2 grid skeleton
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: const [
                      ShimmerBox(
                        width: double.infinity,
                        height: 100,
                      ),
                      SizedBox(height: 12),
                      ShimmerBox(
                        width: double.infinity,
                        height: 100,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: const [
                      ShimmerBox(
                        width: double.infinity,
                        height: 100,
                      ),
                      SizedBox(height: 12),
                      ShimmerBox(
                        width: double.infinity,
                        height: 100,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Section 3: Intelligence insight skeleton
            const ShimmerBox(
              width: double.infinity,
              height: 90,
            ),
            const SizedBox(height: 24),

            // Section 4: Trends chart skeleton
            const ShimmerBox(
              width: double.infinity,
              height: 170,
            ),
            const SizedBox(height: 24),

            // Section 5: Secondary modules skeleton
            const ShimmerBox(width: 100, height: 18, borderRadius: 8),
            const SizedBox(height: 12),
            const ShimmerBox(width: double.infinity, height: 60),
            const SizedBox(height: 8),
            const ShimmerBox(width: double.infinity, height: 60),
            const SizedBox(height: 8),
            const ShimmerBox(width: double.infinity, height: 60),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
