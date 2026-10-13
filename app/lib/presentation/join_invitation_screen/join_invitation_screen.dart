import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/group_change_notifier.dart';
import '../../theme/app_theme.dart';

class JoinInvitationScreen extends StatefulWidget {
  final String token;

  const JoinInvitationScreen({required this.token, super.key});

  @override
  State<JoinInvitationScreen> createState() => _JoinInvitationScreenState();
}

class _JoinInvitationScreenState extends State<JoinInvitationScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _invitation;
  Map<String, dynamic>? _group;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await SupabaseService.instance.getInvitationByToken(
        widget.token,
      );
      if (result == null) {
        setState(() {
          _error = 'La invitación no existe o ha expirado.';
          _isLoading = false;
        });
        return;
      }
      final status = result['status'] as String?;
      if (status != 'prepared' &&
          status != 'pending' &&
          status != 'dispatched') {
        setState(() {
          _error = status == 'accepted'
              ? 'Esta invitación ya fue aceptada.'
              : 'Esta invitación ya no está disponible.';
          _isLoading = false;
        });
        return;
      }
      // Load group info
      final groupData = await SupabaseService.instance.getGroupById(
        result['group_id'] as String,
      );
      setState(() {
        _invitation = result;
        _group = groupData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar la invitación. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvitation() async {
    if (_invitation == null) return;
    final isAuth = SupabaseService.instance.isAuthenticated;
    if (!isAuth) {
      // Redirect to sign-in preserving the token
      context.go(
        '${AppRoutes.signUpLoginScreen}?redirect=/join/${widget.token}',
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // Use the token (UUID string) from the invitation record
      final token = _invitation!['token'] as String;

      // Atomic RPC: validates invitation, inserts membership as role=member,
      // marks invitation accepted — all in one transaction.
      final result = await SupabaseService.instance.acceptInvitationAtomic(
        token,
      );

      if (result.containsKey('error')) {
        final err = result['error'] as String;
        String userMessage;
        switch (err) {
          case 'not_authenticated':
            userMessage = 'Debes iniciar sesión para unirte al grupo.';
            break;
          case 'invitation_not_found':
            userMessage = 'La invitación no existe o ha expirado.';
            break;
          case 'already_accepted':
            userMessage = 'Esta invitación ya fue aceptada anteriormente.';
            break;
          case 'invitation_expired':
            userMessage = 'Esta invitación ha expirado.';
            break;
          case 'invitation_revoked':
            userMessage = 'Esta invitación fue revocada.';
            break;
          default:
            userMessage = 'Error al unirse al grupo: $err';
        }
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _error = userMessage;
          });
        }
        return;
      }

      // Success — get the joined group_id
      final groupId = result['group_id'] as String?;
      final groupName = _group?['name'] as String? ?? 'el grupo';

      // Notify all listeners that groups changed AND set the joined group as active
      GroupChangeNotifier.instance.notifyGroupsChangedWithActiveGroup(groupId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Te has unido a $groupName!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        // Navigate to map — the active group is already set
        context.go(AppRoutes.liveMapScreen);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = 'Error al unirse al grupo. Inténtalo de nuevo.';
        });
      }
    }
  }

  Future<void> _declineInvitation() async {
    if (_invitation == null) return;
    setState(() => _isProcessing = true);
    try {
      // token is the PK of the invitations table
      await SupabaseService.instance.updateInvitationStatus(
        invitationId: _invitation!['token'],
        status: 'revoked',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitación rechazada.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go(AppRoutes.onboardingScreen);
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withAlpha(77),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Invitación a grupo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SentinelFamily',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const CircularProgressIndicator()
                else if (_error != null)
                  _buildErrorState(theme)
                else if (_invitation != null)
                  _buildInvitationCard(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.errorContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppTheme.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _error!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.onboardingScreen),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }

  Widget _buildInvitationCard(ThemeData theme) {
    final groupName = _group?['name'] as String? ?? 'Grupo';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.group_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                groupName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Has sido invitado/a a unirte a este grupo de seguridad.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rol: Miembro',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _isProcessing ? null : _acceptInvitation,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Unirme al grupo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isProcessing ? null : _declineInvitation,
          child: Text(
            'Rechazar invitación',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
