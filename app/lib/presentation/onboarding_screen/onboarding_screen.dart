import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import './widgets/consent_step_widget.dart';
import './widgets/onboarding_landing_widget.dart';
import './widgets/onboarding_stepper_widget.dart';

// TODO: Replace with Riverpod for production — consent state management
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final int _totalSteps =
      6; // 0=landing, 1=terms, 2=data, 3=transparency, 4=security, 5=account

  // 14 granular permissions
  // TODO: Replace with Riverpod for production
  final Map<String, bool> _permissions = {
    'location_exact': false,
    'location_approx': false,
    'location_background': false,
    'battery_status': false,
    'sos_alerts': true, // required
    'group_visibility': false,
    'route_history': false,
    'checkin_notifications': false,
    'convoy_mode': false,
    'ghost_mode': false,
    'contact_access': false,
    'push_notifications': false,
    'analytics_anonymous': false,
    'crash_reports': true, // required
  };

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    // Grant administrator group-creation capability when onboarding completes.
    // Onboarding is the Sentinel administrator setup path.
    await SupabaseService.instance.grantCanCreateGroups();
    if (mounted) {
      context.go(AppRoutes.liveMapScreen);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: _currentStep == 0
            ? OnboardingLandingWidget(
                onGetStarted: _nextStep,
                onLogin: () => context.go(AppRoutes.signUpLoginScreen),
              )
            : Column(
                children: [
                  OnboardingStepperWidget(
                    currentStep: _currentStep - 1,
                    totalSteps: _totalSteps - 1,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: ConsentStepWidget(
                          step: _currentStep,
                          permissions: _permissions,
                          onPermissionChanged: (key, value) {
                            // Required permissions cannot be disabled
                            if (key == 'sos_alerts' || key == 'crash_reports') {
                              return;
                            }
                            setState(() => _permissions[key] = value);
                          },
                          onNext: _nextStep,
                          onBack: _prevStep,
                          isTablet: isTablet,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
