import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class OnboardingStepperWidget extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const OnboardingStepperWidget({
    required this.currentStep,
    required this.totalSteps,
    super.key,
  });

  static const List<String> _stepLabels = [
    'Términos',
    'Datos',
    'Transparencia',
    'Seguridad',
    'Cuenta',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps, (i) {
              final isCompleted = i < currentStep;
              final isActive = i == currentStep;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCompleted || isActive
                              ? AppTheme.primary
                              : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < totalSteps - 1) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paso ${currentStep + 1} de $totalSteps',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (currentStep < _stepLabels.length)
                Text(
                  _stepLabels[currentStep],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
