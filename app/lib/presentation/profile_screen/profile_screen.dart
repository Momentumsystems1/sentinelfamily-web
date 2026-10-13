import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import './widgets/consent_history_widget.dart';
import './widgets/privacy_settings_widget.dart';
import './widgets/profile_form_widget.dart';
import './widgets/profile_header_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _profile = {
    'name': '',
    'email': '',
    'phone': '',
    'imageUrl': null,
    'semanticLabel': 'User profile photo',
    'color': 0xFF1B5E52,
    'symbol': 'shield',
    'plan': 'Free',
    'memberSince': '',
  };

  bool _isLoading = true;
  bool _isSaving = false;

  bool _locationExact = true;
  bool _locationBackground = true;
  bool _batteryStatus = true;
  bool _routeHistory = false;
  bool _checkinNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final profileData = await SupabaseService.instance.getProfile(userId);
      final user = SupabaseService.instance.currentUser;

      if (mounted) {
        setState(() {
          _profile = {
            'name':
                profileData?['display_name'] as String? ??
                user?.email?.split('@').first ??
                'Usuario',
            'email': user?.email ?? '',
            'phone': profileData?['phone'] as String? ?? '',
            'imageUrl': null,
            'semanticLabel': 'User profile photo',
            'color': _hexToInt(
              profileData?['avatar_color'] as String? ?? '#1B5E52',
            ),
            'symbol': profileData?['avatar_symbol'] as String? ?? 'shield',
            'plan': 'Free',
            'memberSince': _formatDate(
              profileData?['created_at'] as String? ?? '',
            ),
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _hexToInt(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return int.parse('FF$h', radix: 16);
    } catch (_) {
      return 0xFF1B5E52;
    }
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return 'Septiembre 2026';
    try {
      final dt = DateTime.parse(isoDate);
      const months = [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Septiembre 2026';
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId != null) {
        await SupabaseService.instance.updateProfile(
          userId: userId,
          displayName: _profile['name'] as String?,
          phone: _profile['phone'] as String?,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Perfil guardado',
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
              ),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await SupabaseService.instance.signOut();
      if (mounted) context.go(AppRoutes.onboardingScreen);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e')));
      }
    }
  }

  void _onPrivacyChanged(String key, bool value) {
    setState(() {
      switch (key) {
        case 'locationExact':
          _locationExact = value;
          break;
        case 'locationBackground':
          _locationBackground = value;
          break;
        case 'batteryStatus':
          _batteryStatus = value;
          break;
        case 'routeHistory':
          _routeHistory = value;
          break;
        case 'checkinNotifications':
          _checkinNotifications = value;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: AppTheme.primaryContainer,
        title: Text(
          'Mi perfil',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Guardar',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: isTablet
          ? _buildTabletLayout(theme)
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                ProfileHeaderWidget(profile: _profile),
                const SizedBox(height: 8),
                ProfileFormWidget(profile: _profile),
                const SizedBox(height: 8),
                PrivacySettingsWidget(
                  locationExact: _locationExact,
                  locationBackground: _locationBackground,
                  batteryStatus: _batteryStatus,
                  routeHistory: _routeHistory,
                  checkinNotifications: _checkinNotifications,
                  onChanged: _onPrivacyChanged,
                ),
                const SizedBox(height: 8),
                const ConsentHistoryWidget(),
                const SizedBox(height: 32),
                _buildDangerZone(theme),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildTabletLayout(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                ProfileHeaderWidget(profile: _profile),
                const SizedBox(height: 16),
                ProfileFormWidget(profile: _profile),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                PrivacySettingsWidget(
                  locationExact: _locationExact,
                  locationBackground: _locationBackground,
                  batteryStatus: _batteryStatus,
                  routeHistory: _routeHistory,
                  checkinNotifications: _checkinNotifications,
                  onChanged: _onPrivacyChanged,
                ),
                const SizedBox(height: 16),
                const ConsentHistoryWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorContainer.withAlpha(77),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.error.withAlpha(51)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ZONA DE PELIGRO',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.error,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showConfirmDialog(
                context,
                'Cerrar sesión',
                '¿Seguro que quieres cerrar sesión? Tu familia ya no podrá verte en el mapa.',
                _signOut,
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: BorderSide(color: AppTheme.error.withAlpha(102)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showConfirmDialog(
                context,
                'Eliminar cuenta',
                'Esta acción es irreversible. Todos tus datos y grupos serán eliminados permanentemente conforme al RGPD Art. 17.',
                () {},
              ),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Eliminar cuenta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: BorderSide(color: AppTheme.error.withAlpha(102)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
