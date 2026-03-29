import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Detailed nutrition breakdown with tabs for Macros, Calories, Heart Healthy, Low Carb.
/// Full implementation in P14-012.
class NutritionDetailScreen extends StatelessWidget {
  const NutritionDetailScreen({super.key, this.initialTab});
  final String? initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Nutrition Details'),
      ),
      body: Center(
        child: Text(
          'Nutrition Detail — ${initialTab ?? 'macros'} tab\nFull implementation coming in P14-012',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
