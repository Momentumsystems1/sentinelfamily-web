import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../routes/app_routes.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

class ConsentStepWidget extends StatefulWidget {
  final int step;
  final Map<String, bool> permissions;
  final Function(String, bool) onPermissionChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isTablet;

  const ConsentStepWidget({
    required this.step,
    required this.permissions,
    required this.onPermissionChanged,
    required this.onNext,
    required this.onBack,
    required this.isTablet,
    super.key,
  });

  @override
  State<ConsentStepWidget> createState() => _ConsentStepWidgetState();
}

class _ConsentStepWidgetState extends State<ConsentStepWidget> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await SupabaseService.instance.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      if (mounted) {
        context.go(AppRoutes.liveMapScreen);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al crear cuenta. Inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.step) {
      case 1:
        return _buildTermsStep(theme);
      case 2:
        return _buildDataStep(theme);
      case 3:
        return _buildTransparencyStep(theme);
      case 4:
        return _buildSecurityStep(theme);
      case 5:
        return _buildAccountStep(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTermsStep(ThemeData theme) {
    return _StepShell(
      icon: Icons.gavel_rounded,
      title: 'Términos de uso',
      subtitle: 'Momentum Systems S.L. — v2.1 — 07/09/2026',
      onNext: widget.onNext,
      onBack: widget.onBack,
      nextLabel: 'Acepto y continúo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legalParagraph(
            theme,
            'SentinelFamily es un servicio de coordinación familiar. El uso implica la aceptación de estos términos redactados conforme al RGPD y la Ley Orgánica 3/2018 de Protección de Datos Personales.',
          ),
          const SizedBox(height: 12),
          _legalParagraph(
            theme,
            'Los datos de ubicación se procesan exclusivamente para las funciones de coordinación familiar que el usuario habilite explícitamente. Momentum Systems S.L. no vende datos a terceros bajo ninguna circunstancia.',
          ),
          const SizedBox(height: 12),
          _legalParagraph(
            theme,
            'El usuario puede revocar cualquier permiso en cualquier momento desde Perfil → Configuración de privacidad. La revocación surte efecto inmediato.',
          ),
          const SizedBox(height: 12),
          _highlightBox(
            theme,
            Icons.info_outline_rounded,
            'Versión 2.1 — Última revisión: 07/09/2026. Puedes exportar tu historial de consentimientos en cualquier momento (RGPD Art. 20).',
          ),
        ],
      ),
    );
  }

  Widget _buildDataStep(ThemeData theme) {
    final locationPerms = [
      _PermDef(
        'location_exact',
        'Ubicación exacta',
        'GPS preciso para el mapa en vivo. Compartido solo con tu grupo familiar.',
        Icons.gps_fixed_rounded,
      ),
      _PermDef(
        'location_approx',
        'Ubicación aproximada',
        'Área de ~500m en lugar de coordenadas exactas. Más privado.',
        Icons.location_searching_rounded,
      ),
      _PermDef(
        'location_background',
        'Ubicación en segundo plano',
        'Permite el mapa cuando la app está cerrada. Consume más batería.',
        Icons.location_on_outlined,
      ),
      _PermDef(
        'battery_status',
        'Estado de batería',
        'Tu familia ve tu nivel de batería para saber si pierdes conexión.',
        Icons.battery_4_bar_rounded,
      ),
      _PermDef(
        'route_history',
        'Historial de rutas',
        'Guarda tus rutas de las últimas 24h. Solo tú y admins del grupo.',
        Icons.route_rounded,
      ),
    ];
    return _StepShell(
      icon: Icons.storage_rounded,
      title: 'Permisos de datos',
      subtitle: 'Activa solo lo que necesites. Puedes cambiar esto después.',
      onNext: widget.onNext,
      onBack: widget.onBack,
      child: Column(
        children: locationPerms
            .map((p) => _buildPermissionTile(theme, p))
            .toList(),
      ),
    );
  }

  Widget _buildTransparencyStep(ThemeData theme) {
    final socialPerms = [
      _PermDef(
        'group_visibility',
        'Visibilidad en el grupo',
        'Aparecer en el mapa de tu familia cuando compartes ubicación.',
        Icons.visibility_rounded,
      ),
      _PermDef(
        'checkin_notifications',
        'Notificaciones de llegada',
        'Avisar a tu familia cuando llegas a un destino.',
        Icons.notifications_active_rounded,
      ),
      _PermDef(
        'convoy_mode',
        'Modo convoy',
        'Participar como líder o copiloto en viajes en grupo.',
        Icons.directions_car_rounded,
      ),
      _PermDef(
        'ghost_mode',
        'Modo fantasma',
        'Ocultarte temporalmente del mapa sin revocar permisos permanentes.',
        Icons.visibility_off_rounded,
      ),
      _PermDef(
        'contact_access',
        'Acceso a contactos',
        'Invitar miembros del grupo seleccionando de tu agenda.',
        Icons.contacts_rounded,
      ),
    ];
    return _StepShell(
      icon: Icons.visibility_rounded,
      title: 'Transparencia',
      subtitle: 'Controla qué ven los demás miembros de tu grupo.',
      onNext: widget.onNext,
      onBack: widget.onBack,
      child: Column(
        children: socialPerms
            .map((p) => _buildPermissionTile(theme, p))
            .toList(),
      ),
    );
  }

  Widget _buildSecurityStep(ThemeData theme) {
    final securityPerms = [
      _PermDef(
        'sos_alerts',
        'Alertas SOS',
        'Requerido para enviar y recibir emergencias. No se puede desactivar.',
        Icons.sos_rounded,
        required: true,
      ),
      _PermDef(
        'push_notifications',
        'Notificaciones push',
        'Recibir alertas de tu familia aunque la app esté cerrada.',
        Icons.notifications_rounded,
      ),
      _PermDef(
        'analytics_anonymous',
        'Analíticas anónimas',
        'Datos agregados y anónimos para mejorar el servicio. Sin identificación personal.',
        Icons.analytics_outlined,
      ),
      _PermDef(
        'crash_reports',
        'Informes de error',
        'Requerido para mantener la estabilidad del servicio. No incluye datos personales.',
        Icons.bug_report_outlined,
        required: true,
      ),
    ];
    return _StepShell(
      icon: Icons.security_rounded,
      title: 'Seguridad y alertas',
      subtitle: 'Configura cómo recibes y envías alertas de seguridad.',
      onNext: widget.onNext,
      onBack: widget.onBack,
      child: Column(
        children: [
          ...securityPerms.map((p) => _buildPermissionTile(theme, p)),
          const SizedBox(height: 12),
          _highlightBox(
            theme,
            Icons.shield_rounded,
            'El botón SOS es accesible con pantalla bloqueada. Activa notificaciones push para garantizar que tu familia reciba alertas de emergencia.',
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStep(ThemeData theme) {
    return _StepShell(
      icon: Icons.person_add_rounded,
      title: 'Crear cuenta',
      subtitle: 'Tu cuenta en Momentum Systems S.L.',
      onNext: _isLoading ? () {} : _handleCreateAccount,
      onBack: widget.onBack,
      nextLabel: 'Crear cuenta',
      isLoading: _isLoading,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Introduce tu nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Introduce tu email';
                if (!v.contains('@')) return 'Email no válido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 8) return 'Mínimo 8 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _highlightBox(
              theme,
              Icons.lock_rounded,
              'Tu contraseña se cifra con bcrypt antes de guardarse. Momentum Systems S.L. nunca puede leer tu contraseña.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(ThemeData theme, _PermDef perm) {
    final isEnabled = widget.permissions[perm.key] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppTheme.primaryContainer.withAlpha(77)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? AppTheme.primary.withAlpha(77)
              : theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEnabled
                ? AppTheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            perm.icon,
            color: isEnabled
                ? AppTheme.primary
                : theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                perm.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (perm.required)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Requerido',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          perm.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        trailing: Switch(
          value: isEnabled,
          onChanged: perm.required
              ? null
              : (v) => widget.onPermissionChanged(perm.key, v),
          activeThumbColor: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _legalParagraph(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.6,
      ),
    );
  }

  Widget _highlightBox(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(51)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.primary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermDef {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final bool required;

  _PermDef(
    this.key,
    this.title,
    this.description,
    this.icon, {
    this.required = false,
  });
}

class _StepShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final String nextLabel;
  final bool isLoading;

  const _StepShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onNext,
    required this.onBack,
    this.nextLabel = 'Continuar',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: AppTheme.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.headlineSmall),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: isLoading ? null : onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isLoading ? null : onNext,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(nextLabel),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
