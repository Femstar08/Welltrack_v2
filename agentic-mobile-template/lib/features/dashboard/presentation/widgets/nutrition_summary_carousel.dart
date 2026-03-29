import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../shared/core/theme/app_colors.dart';
import '../../../meals/presentation/today_nutrition_provider.dart';
import 'shimmer_loading.dart';
import 'macro_rings_carousel_page.dart';
import 'calories_budget_carousel_page.dart';
import 'heart_healthy_carousel_page.dart';
import 'low_carb_carousel_page.dart';

/// 4-page nutrition carousel for the dashboard: Macros, Calories, Heart Healthy, Low Carb.
class NutritionSummaryCarousel extends ConsumerStatefulWidget {
  const NutritionSummaryCarousel({
    super.key,
    required this.profileId,
  });

  final String profileId;

  @override
  ConsumerState<NutritionSummaryCarousel> createState() =>
      _NutritionSummaryCarouselState();
}

class _NutritionSummaryCarouselState
    extends ConsumerState<NutritionSummaryCarousel> {
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync =
        ref.watch(todayNutritionDashboardProvider(widget.profileId));

    return dashboardAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: ShimmerBox(width: double.infinity, height: 180, borderRadius: 24),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              'Nutrition data unavailable',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ),
        ),
      ),
      data: (dashboard) {
        // Zero-state: no food logged
        final totalConsumed =
            dashboard.protein.consumed +
            dashboard.carbs.consumed +
            dashboard.fat.consumed;
        if (totalConsumed == 0) {
          return _buildZeroState(context);
        }

        return _buildCarousel(context, dashboard);
      },
    );
  }

  Widget _buildZeroState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.restaurant_menu,
                color: AppColors.textSecondaryDark,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'No food logged today',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/meals/food-search'),
                child: const Text('Log your first meal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel(BuildContext context, TodayNutritionDashboard dashboard) {
    const routes = [
      '/nutrition?tab=macros',
      '/nutrition?tab=calories',
      '/nutrition?tab=heart',
      '/nutrition?tab=lowcarb',
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            child: PageView(
              controller: _pageController,
              children: [
                GestureDetector(
                  onTap: () => context.push(routes[0]),
                  child: MacroRingsCarouselPage(
                    protein: dashboard.protein,
                    carbs: dashboard.carbs,
                    fat: dashboard.fat,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push(routes[1]),
                  child: CaloriesBudgetCarouselPage(
                    calories: dashboard.calories,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push(routes[2]),
                  child: HeartHealthyCarouselPage(
                    micro: dashboard.micro,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push(routes[3]),
                  child: LowCarbCarouselPage(
                    micro: dashboard.micro,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SmoothPageIndicator(
            controller: _pageController,
            count: 4,
            effect: const WormEffect(
              dotWidth: 8,
              dotHeight: 8,
              spacing: 6,
              dotColor: AppColors.surfaceContainerHighest,
              activeDotColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
