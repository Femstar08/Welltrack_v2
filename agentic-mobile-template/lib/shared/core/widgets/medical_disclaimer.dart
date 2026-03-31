import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Persistent medical disclaimer shown on health recommendation screens.
/// Required by Google Play Health & Fitness policy.
class MedicalDisclaimer extends StatelessWidget {
  const MedicalDisclaimer({super.key});

  static const _text =
      'This app provides wellness suggestions only and is not a substitute '
      'for professional medical advice. Consult your doctor before making '
      'health decisions.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: AppColors.textSecondaryDark.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _text,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondaryDark.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
