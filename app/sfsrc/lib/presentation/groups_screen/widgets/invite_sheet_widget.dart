import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

class InviteSheetWidget extends StatefulWidget {
  final String groupName;
  final String groupId;

  const InviteSheetWidget({
    super.key,
    required this.groupName,
    required this.groupId,
  });

  @override
  State<InviteSheetWidget> createState() => _InviteSheetWidgetState();
}

class _InviteSheetWidgetState extends State<InviteSheetWidget> {
  final _phoneCtrl = TextEditingController();
  bool _isCreatingLink = false;
  bool _linkError = false;
  String? _inviteToken;
  String? _inviteLink;

  /// Base del enlace de invitación. Por defecto usa el esquema propio de la
  /// app (sentinelfamily://app/join/<token>) para abrir directamente el APK
  /// instalado. Se puede sobrescribir en compilación con:
  /// --dart-define=INVITE_BASE_URL=https://tudominio.com
  static const String _inviteBase = String.fromEnvironment(
    'INVITE_BASE_URL',
    defaultValue: 'sentinelfamily://app',
  );

  @override
  void initState() {
    super.initState();
    _generateInviteLink();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateInviteLink() async {
    setState(() => _isCreatingLink = true);
    try {
      final invitation = await SupabaseService.instance.createInvitation(
        groupId: widget.groupId,
      );
      if (invitation != null && mounted) {
        final token = invitation['token'] as String;
        setState(() {
          _inviteToken = token;
          _inviteLink = '$_inviteBase/join/$token';
          _isCreatingLink = false;
        });
      } else if (mounted) {
        setState(() {
          _linkError = true;
          _isCreatingLink = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _linkError = true;
          _isCreatingLink = false;
        });
      }
    }
  }

  void _showLinkError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No se pudo generar el enlace. Inténtalo de nuevo.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _shareViaWhatsApp({String? phone}) async {
    final link = _inviteLink;
    if (link == null) {
      _showLinkError();
      return;
    }
    final message = Uri.encodeComponent(
      '¡Únete a mi grupo "${widget.groupName}" en SentinelFamily! 🛡️\n\n$link',
    );
    final url = phone != null && phone.isNotEmpty
        ? 'https://wa.me/${phone.replaceAll(RegExp(r'[^0-9+]'), '')}?text=$message'
        : 'https://wa.me/?text=$message';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _copyToClipboard();
    }
  }

  Future<void> _shareViaSMS({String? phone}) async {
    final link = _inviteLink;
    if (link == null) {
      _showLinkError();
      return;
    }
    final message = Uri.encodeComponent(
      '¡Únete a mi grupo "${widget.groupName}" en SentinelFamily! $link',
    );
    final url = phone != null && phone.isNotEmpty
        ? 'sms:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}?body=$message'
        : 'sms:?body=$message';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copyToClipboard();
    }
  }

  void _copyToClipboard() {
    if (_inviteLink == null) return;
    Clipboard.setData(ClipboardData(text: _inviteLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Enlace copiado al portapapeles',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitar al grupo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      widget.groupName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Invite link display
          if (_isCreatingLink)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Generando enlace de invitación...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else if (_linkError)
            GestureDetector(
              onTap: _generateInviteLink,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer.withAlpha(77),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.error.withAlpha(102)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No se pudo generar el enlace. Toca para reintentar.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.error,
                      size: 16,
                    ),
                  ],
                ),
              ),
            )
          else if (_inviteLink != null)
            GestureDetector(
              onTap: _copyToClipboard,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _inviteLink!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.copy_rounded, color: AppTheme.primary, size: 16),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Optional phone number
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Número de teléfono (opcional)',
              hintText: '+34 612 345 678',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 16),

          // Share buttons
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () => _shareViaWhatsApp(phone: _phoneCtrl.text),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareButton(
                  icon: Icons.sms_rounded,
                  label: 'SMS',
                  color: const Color(0xFF1565C0),
                  onTap: () => _shareViaSMS(phone: _phoneCtrl.text),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShareButton(
                  icon: Icons.copy_rounded,
                  label: 'Copiar',
                  color: AppTheme.primary,
                  onTap: _copyToClipboard,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Privacy note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer.withAlpha(77),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'El enlace expira en 7 días. Solo quien lo reciba puede unirse al grupo.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
