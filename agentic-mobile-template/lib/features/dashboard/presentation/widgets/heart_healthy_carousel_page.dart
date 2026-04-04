import 'package:flutter/material.dart';
import '../../../freemium/presentation/freemium_gate_widget.dart';
import '../../../meals/presentation/today_nutrition_provider.dart';
import 'nutrient_progress_bar.dart';

/// Page 3 of NutritionSummaryCarousel — Heart Healthy nutrients (PRO-gated).
class HeartHealthyCarouselPage extends StatelessWidget {
  const HeartHealthyCarouselPage({
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
        description: 'Track heart-healthy nutrients with Pro',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Heart Healthy',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            NutrientProgressBar(
              label: 'Fat',
              consumed: (micro.fatG ?? 0).toDouble(),
              goal: 65, // FDA daily value
              isNull: micro.fatG == null,
            ),
            NutrientProgressBar(
              label: 'Sodium',
              consumed: (micro.sodiumMg ?? 0).toDouble(),
              goal: 2300, // FDA daily value mg
              isNull: micro.sodiumMg == null,
            ),
            NutrientProgressBar(
              label: 'Cholesterol',
              consumed: (micro.cholesterolMg ?? 0).toDouble(),
              goal: 300, // FDA daily value mg
              isNull: micro.cholesterolMg == null,
            ),
          ],
        ),
      ),
    );
  }
}
