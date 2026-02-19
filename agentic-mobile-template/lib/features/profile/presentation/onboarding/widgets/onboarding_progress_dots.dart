import 'package:flutter/material.dart';
class OnboardingProgressDots extends StatelessWidget {

  const OnboardingProgressDots({
    super.key,
    required this.currentPage,
    this.totalPages = 7,
  });
  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        final isPast = index < currentPage;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : isPast
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
