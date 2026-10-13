// P1 §3.3 — Autorización de círculos nuevos (REGLA DE JUAN)
// Dos widgets nuevos para la app Flutter:
//  1. CreateCircleSection → en la pantalla de Perfil (profile_screen).
//     Popup con COPY LITERAL DE JUAN — no cambiar ni una coma.
//  2. CircleRequestsInbox → en groups_screen, visible solo para owner/admin.
// Requieren los métodos P1 de supabase_service_p1.dart.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

// ─── 1. PERFIL: "Crear mi propio círculo" ──────────────────
class CreateCircleSection extends StatefulWidget {
  final String groupId; // grupo activo del usuario
  const CreateCircleSection({super.key, required this.groupId});

  @override
  State<CreateCircleSection> createState() => _CreateCircleSectionState();
}

class _CreateCircleSectionState extends State<CreateCircleSection> {
  final _nameCtrl = TextEditingController();
  bool _sending = false;
  Map<String, dynamic>? _myRequest;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await SupabaseService.instance.getMyLatestCircleRequest();
    if (mounted) setState(() => _myRequest = r);
  }

  Future<void> _send() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final err = await SupabaseService.instance.createCircleRequest(
      groupId: widget.groupId,
      desiredName: _nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (err == null) {
      Navigator.pop(context);
      _nameCtrl.clear();
      _load();
    } else {
      setState(() => _error =
          err == 'already_pending' ? 'Ya tienes una solicitud pendiente' : 'No se pudo enviar la solicitud');
    }
  }

  void _openDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          // COPY LITERAL DE JUAN — no cambiar ni una coma
          'Para crear tu círculo necesitas autorización del administrador',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre del círculo',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          TextButton(
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'Enviando…' : 'Enviar',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _myRequest?['status'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _openDialog,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: Text('Crear mi propio círculo',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        ),
        if (status == 'pending')
          Text('Solicitud enviada · pendiente',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
        if (status == 'approved')
          Text('¡Aceptada! Ya eres administrador de ${_myRequest!['desired_name']}',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.success)),
        if (status == 'denied')
          Text('Denegada por el administrador',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// ─── 2. GRUPOS: bandeja del admin (Aceptar / Denegar) ──────
class CircleRequestsInbox extends StatefulWidget {
  final String groupId;
  final bool isAdmin; // owner o admin del grupo
  const CircleRequestsInbox({super.key, required this.groupId, required this.isAdmin});

  @override
  State<CircleRequestsInbox> createState() => _CircleRequestsInboxState();
}

class _CircleRequestsInboxState extends State<CircleRequestsInbox> {
  List<Map<String, dynamic>> _requests = [];
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.isAdmin) return;
    final r = await SupabaseService.instance.getPendingCircleRequests(widget.groupId);
    if (mounted) setState(() => _requests = r);
  }

  Future<void> _decide(String id, bool approve) async {
    final result = await SupabaseService.instance.decideCircleRequest(
      requestId: id,
      approve: approve,
    );
    if (!mounted) return;
    if (result.containsKey('error')) {
      setState(() => _feedback = 'No se pudo procesar la solicitud (${result['error']})');
    } else {
      setState(() => _feedback = approve ? 'Solicitud aceptada' : 'Solicitud denegada');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin || _requests.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Solicitudes de círculo nuevo',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 15, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        ..._requests.map((r) {
          final requester = r['requester'] as Map<String, dynamic>?;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(requester?['display_name'] as String? ?? 'Miembro',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('Quiere crear el círculo “${r['desired_name']}”',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decide(r['id'] as String, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                    child: const Text('Aceptar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(r['id'] as String, false),
                    child: const Text('Denegar'),
                  ),
                ),
              ]),
            ]),
          );
        }),
        if (_feedback != null)
          Text(_feedback!, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
      ],
    );
  }
}
