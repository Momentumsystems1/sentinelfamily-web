// P1 — SUSTITUYE a lib/presentation/groups_screen/widgets/invite_sheet_widget.dart
// Cambios respecto a la versión actual:
//  1. Campo nombre del invitado (invitee_name — para el saludo personalizado).
//  2. Selector fijo/temporal + duración D4 (24 h / 7 días / 30 días / fecha personalizada).
//     Sin duración elegida NO se puede generar el enlace.
//  3. La invitación se crea AL PULSAR "Crear enlace" (no en initState) — antes
//     hace falta saber membership + duración.
//  4. ELIMINADO el fallback '/join/demo' (PROHIBIDO: simulación + palabra vetada).
//     Si falla la creación, se muestra error honesto y no se comparte nada.
//  5. Marca 'dispatched' solo cuando el SO confirma apertura del canal.
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
  static const _webBase = 'https://sentinelfa7804.builtwithrocket.new';

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _membership = 'fixed'; // 'fixed' | 'temporary'
  int? _durationHours; // 24, 168 (7d), 720 (30d) o null si fecha personalizada
  DateTime? _customDate;

  bool _isCreatingLink = false;
  String? _inviteToken;
  String? _inviteLink;
  DateTime? _expiresAt;
  String? _createError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _canCreate {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_membership == 'temporary') {
      return _durationHours != null || _customDate != null;
    }
    return true;
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Fin del acceso del invitado',
    );
    if (picked != null) {
      setState(() {
        _customDate = picked;
        _durationHours = null; // la fecha personalizada manda
      });
    }
  }

  Future<void> _createLink() async {
    if (!_canCreate) return;
    setState(() {
      _isCreatingLink = true;
      _createError = null;
    });

    DateTime? expires;
    if (_membership == 'temporary') {
      expires = _customDate != null
          ? DateTime(_customDate!.year, _customDate!.month, _customDate!.day, 23, 59)
          : DateTime.now().add(Duration(hours: _durationHours!));
    }

    final invitation = await SupabaseService.instance.createInvitation(
      groupId: widget.groupId,
      inviteeName: _nameCtrl.text.trim(),
      membership: _membership,
      expiresAt: expires?.toUtc().toIso8601String(),
    );

    if (!mounted) return;
    if (invitation == null) {
      // Etiqueta honesta: NUNCA un enlace simulado
      setState(() {
        _isCreatingLink = false;
        _createError = 'No se pudo crear la invitación. Inténtalo de nuevo.';
      });
      return;
    }
    final token = invitation['token'] as String;
    setState(() {
      _inviteToken = token;
      _inviteLink = '$_webBase/join/$token';
      _expiresAt = expires;
      _isCreatingLink = false;
    });
  }

  String get _shareMessage {
    final expiry = _membership == 'temporary' && _expiresAt != null
        ? ' (acceso hasta el ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year})'
        : '';
    return 'Hola ${_nameCtrl.text.trim()}, te invito a mi círculo "${widget.groupName}" '
        'en Sentinel Family$expiry. Abre este enlace para unirte: $_inviteLink';
  }

  Future<void> _shareViaWhatsApp() async {
    final message = Uri.encodeComponent(_shareMessage);
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = phone.isNotEmpty ? 'https://wa.me/$phone?text=$message' : 'https://wa.me/?text=$message';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (_inviteToken != null) {
        SupabaseService.instance.markInvitationDispatched(_inviteToken!);
      }
    } else {
      _copyToClipboard();
    }
  }

  Future<void> _shareViaSMS() async {
    final message = Uri.encodeComponent(_shareMessage);
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = phone.isNotEmpty ? 'sms:$phone?body=$message' : 'sms:?body=$message';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (_inviteToken != null) {
        SupabaseService.instance.markInvitationDispatched(_inviteToken!);
      }
    } else {
      _copyToClipboard();
    }
  }

  void _copyToClipboard() {
    if (_inviteLink == null) return;
    Clipboard.setData(ClipboardData(text: _inviteLink!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enlace copiado al portapapeles',
            style: GoogleFonts.plusJakartaSans(fontSize: 13)),
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
        left: 20, right: 20, top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Invitar al círculo',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface)),
            Text(widget.groupName,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),

            // Nombre del invitado (saludo personalizado en su bienvenida)
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nombre de la persona invitada',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Fijo / temporal
            Text('¿Cómo participará?',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ChoiceCard(
                icon: Icons.all_inclusive,
                title: 'Miembro fijo',
                subtitle: 'Sin expiración',
                selected: _membership == 'fixed',
                onTap: () => setState(() => _membership = 'fixed'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _ChoiceCard(
                icon: Icons.timer_outlined,
                title: 'Invitado temporal',
                subtitle: 'Con expiración',
                selected: _membership == 'temporary',
                onTap: () => setState(() => _membership = 'temporary'),
              )),
            ]),

            // D4: duración a elección de quien invita
            if (_membership == 'temporary') ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _DurationChip(label: '24 h', selected: _durationHours == 24,
                    onTap: () => setState(() { _durationHours = 24; _customDate = null; })),
                _DurationChip(label: '7 días', selected: _durationHours == 168,
                    onTap: () => setState(() { _durationHours = 168; _customDate = null; })),
                _DurationChip(label: '30 días', selected: _durationHours == 720,
                    onTap: () => setState(() { _durationHours = 720; _customDate = null; })),
                _DurationChip(
                  label: _customDate != null
                      ? '${_customDate!.day}/${_customDate!.month}/${_customDate!.year}'
                      : 'Fecha personalizada',
                  selected: _customDate != null,
                  onTap: _pickCustomDate,
                ),
              ]),
            ],
            const SizedBox(height: 16),

            // Crear enlace (deshabilitado hasta tener nombre + duración si temporal)
            if (_inviteLink == null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canCreate && !_isCreatingLink ? _createLink : null,
                  icon: _isCreatingLink
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.link_rounded, size: 18),
                  label: Text(_isCreatingLink ? 'Creando enlace…' : 'Crear enlace de invitación',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_createError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_createError!,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red)),
                ),
            ] else ...[
              GestureDetector(
                onTap: _copyToClipboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withAlpha(51)),
                  ),
                  child: Row(children: [
                    Icon(Icons.link_rounded, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_inviteLink!,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.primary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Icon(Icons.copy_rounded, color: AppTheme.primary, size: 16),
                  ]),
                ),
              ),
              if (_expiresAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Invitación temporal · acceso hasta el ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Número de teléfono (opcional)',
                  hintText: '+34 612 345 678',
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _ShareButton(icon: Icons.chat_rounded, label: 'WhatsApp',
                    color: const Color(0xFF25D366), onTap: _shareViaWhatsApp)),
                const SizedBox(width: 10),
                Expanded(child: _ShareButton(icon: Icons.sms_rounded, label: 'SMS',
                    color: const Color(0xFF1565C0), onTap: _shareViaSMS)),
                const SizedBox(width: 10),
                Expanded(child: _ShareButton(icon: Icons.copy_rounded, label: 'Copiar',
                    color: AppTheme.primary, onTap: _copyToClipboard)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceCard({required this.icon, required this.title, required this.subtitle,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppTheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1),
          color: selected ? AppTheme.primaryContainer.withAlpha(60) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: selected ? AppTheme.primary : theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(subtitle, style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DurationChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary.withAlpha(40),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ShareButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
