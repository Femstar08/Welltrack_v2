import 'package:flutter/material.dart';
import '../../../freemium/presentation/freemium_gate_widget.dart';
import '../../../meals/presentation/today_nutrition_provider.dart';
import 'nutrient_progress_bar.dart';

/// Page 4 of NutritionSummaryCarousel — Low Carb nutrients (PRO-gated).
class LowCarbCarouselPage extends StatelessWidget {
  const LowCarbCarouselPage({
    super.key,
    required this.micro,
  });

  final MicronutrientSummary micro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FreemiumGate(
        featureName: 'full_nutrients',
        description: 'Track low-carb nutrients with Pro',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Low Carb',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            NutrientProgressBar(
              label: 'Carbs',
              consumed: (micro.carbsG ?? 0).toDouble(),
              goal: 275, // FDA daily value
              isNull: micro.carbsG == null,
            ),
            NutrientProgressBar(
              label: 'Sugar',
              consumed: (micro.sugarG ?? 0).toDouble(),
              goal: 50, // FDA daily value
              isNull: micro.sugarG == null,
            ),
            NutrientProgressBar(
              label: 'Fiber',
              consumed: (micro.fiberG ?? 0).toDouble(),
              goal: 28, // FDA daily value
              isNull: micro.fiberG == null,
            ),
          ],
        ),
      ),
    );
  }
}
