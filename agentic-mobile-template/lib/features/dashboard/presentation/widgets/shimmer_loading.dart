import 'package:flutter/material.dart';

/// Shimmer effect widget — no external packages needed.
/// Uses AnimationController + LinearGradient + ShaderMask.
class ShimmerBox extends StatelessWidget {

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });
  final double width;
  final double height;
  final double borderRadius;

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
      child: const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 60),

            // Header: greeting + name
            ShimmerBox(width: 140, height: 18, borderRadius: 8),
            SizedBox(height: 8),
            ShimmerBox(width: 200, height: 28, borderRadius: 8),
            SizedBox(height: 24),

            // Recovery Score card
            ShimmerBox(
              width: double.infinity,
              height: 80,
              borderRadius: 16,
            ),
            SizedBox(height: 24),

            // Nutrition Carousel
            ShimmerBox(
              width: double.infinity,
              height: 180,
              borderRadius: 24,
            ),
            SizedBox(height: 32),

            // Steps + Exercise tiles (side-by-side)
            Row(
              children: [
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 120,
                    borderRadius: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 120,
                    borderRadius: 24,
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),

            // Weight Trend Chart
            ShimmerBox(
              width: double.infinity,
              height: 190,
              borderRadius: 16,
            ),
            SizedBox(height: 32),

            // Bloodwork + Habit cards
            ShimmerBox(
              width: double.infinity,
              height: 80,
              borderRadius: 24,
            ),
            SizedBox(height: 16),
            ShimmerBox(
              width: double.infinity,
              height: 60,
              borderRadius: 12,
            ),
            SizedBox(height: 32),

            // Discover grid (2x2)
            Row(
              children: [
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 56,
                    borderRadius: 12,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 56,
                    borderRadius: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 56,
                    borderRadius: 12,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ShimmerBox(
                    width: double.infinity,
                    height: 56,
                    borderRadius: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
