import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import './person_map_object_widget.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PersonDetailSheet — unified bottom sheet for self and other members.
///
/// isSelf = true  → Self sheet (edit profile, change photo, own actions)
/// isSelf = false → Member sheet (¿Todo bien?, Enviar mensaje, Enviar sitio)
///
/// REAL actions:
///   Self:
///     - Consultar / editar ficha (real)
///     - Cambiar foto (real upload to Supabase Storage)
///     - ¿Todo ok? (real alert_events insert, no target_user_id for self)
///     - Enviar sitio (real GPS via share_plus)
///     - Enviar mensaje → unavailable (no messaging backend)
///   Other member:
///     - Consultar ficha (read-only view)
///     - Últimos movimientos (real DB query)
///     - ¿Todo bien? (real alert_events insert WITH target_user_id)
///     - Enviar mensaje (real phone/WhatsApp if phone available)
///     - Enviar sitio (real GPS via share_plus)
/// ═══════════════════════════════════════════════════════════════════════════
class PersonDetailSheet extends StatefulWidget {
  final PersonMapData data;
  final bool isSelf;
  final String? groupId;
  final String? groupName;
  // Own-user specific
  final double? currentLat;
  final double? currentLng;
  final DateTime? lastLocationUpdate;
  final VoidCallback? onProfileUpdated;

  const PersonDetailSheet({
    required this.data,
    required this.isSelf,
    this.groupId,
    this.groupName,
    this.currentLat,
    this.currentLng,
    this.lastLocationUpdate,
    this.onProfileUpdated,
    super.key,
  });

  @override
  State<PersonDetailSheet> createState() => _PersonDetailSheetState();
}

class _PersonDetailSheetState extends State<PersonDetailSheet> {
  bool _uploadingPhoto = false;
  String? _localPhotoUrl;

  @override
  void initState() {
    super.initState();
    _localPhotoUrl = widget.data.avatarUrl;
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  String get _initial => widget.data.displayName.isNotEmpty
      ? widget.data.displayName[0].toUpperCase()
      : 'S';

  String get _movementLabel {
    switch (widget.data.movementState) {
      case PersonMovementState.moving:
        return 'En movimiento';
      case PersonMovementState.stopped:
        return 'Parado';
      case PersonMovementState.unknown:
        return 'Desconocido';
    }
  }

  IconData get _movementIcon {
    switch (widget.data.movementState) {
      case PersonMovementState.moving:
        return Icons.directions_walk_rounded;
      case PersonMovementState.stopped:
        return Icons.pause_circle_outline_rounded;
      case PersonMovementState.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get _movementColor {
    switch (widget.data.movementState) {
      case PersonMovementState.moving:
        return AppTheme.success;
      case PersonMovementState.stopped:
        return AppTheme.warning;
      case PersonMovementState.unknown:
        return AppTheme.statusOffline;
    }
  }

  String get _activityLabel {
    switch (widget.data.activityState) {
      case PersonActivityState.normal:
        return 'Sin actividad';
      case PersonActivityState.route:
        return 'En ruta';
      case PersonActivityState.meeting:
        return 'En quedada';
      case PersonActivityState.convoy:
        return 'En convoy';
    }
  }

  // ─── PHOTO UPLOAD (self only) ─────────────────────────────────────────────

  Future<void> _changePhoto() async {
    if (!widget.isSelf) return;
    final source = await _pickImageSource();
    if (source == null) return;

    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) {
        _showSnack('No se pudo acceder a la cámara/galería', isError: true);
      }
      return;
    }
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('No autenticado');

      final bytes = await picked.readAsBytes();
      final rawExt = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final ext = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(rawExt)
          ? rawExt
          : 'jpg';
      final storagePath = '$userId/profile.$ext';

      debugPrint('[Photo] Uploading to bucket=avatars path=$storagePath');

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      debugPrint('[Photo] Public URL: $publicUrl');

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      debugPrint('[Photo] profiles.avatar_url updated successfully');

      if (mounted) {
        setState(() {
          _localPhotoUrl = publicUrl;
          _uploadingPhoto = false;
        });
        _showSnack('Foto actualizada');
        widget.onProfileUpdated?.call();
      }
    } catch (e) {
      debugPrint('[Photo] UPLOAD ERROR: ${e.runtimeType}: $e');
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        _showSnack('Error al subir la foto: ${e.toString()}', isError: true);
      }
    }
  }

  Future<ImageSource?> _pickImageSource() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACTIONS ─────────────────────────────────────────────────────────────

  Future<void> _consultarFicha() async {
    if (widget.isSelf) {
      Navigator.pop(context);
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _EditProfileSheet(
          displayName: widget.data.displayName,
          onSaved: () => widget.onProfileUpdated?.call(),
        ),
      );
    } else {
      // Read-only member profile view
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MemberProfileSheet(data: widget.data),
      );
    }
  }

  Future<void> _ultimosMovimientos() async {
    final userId = widget.isSelf
        ? SupabaseService.instance.currentUserId
        : widget.data.userId;
    if (userId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final rows = await Supabase.instance.client
          .from('locations')
          .select('lat, lng, updated_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(20);

      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      final locations = List<Map<String, dynamic>>.from(rows as List);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MovementHistorySheet(locations: locations),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Error al cargar historial', isError: true);
      }
    }
  }

  Future<void> _todoOk() async {
    final groupId = widget.groupId;
    if (groupId == null) {
      _showSnack('Selecciona un grupo primero');
      return;
    }

    final targetName = widget.isSelf ? 'tu grupo' : widget.data.displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppTheme.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text('¿Todo bien?'),
          ],
        ),
        content: Text(
          widget.isSelf
              ? 'Se enviará una señal de "Todo ok" a $targetName.'
              : 'Se enviará una señal de "¿Todo bien?" a $targetName.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final lat = widget.currentLat;
      final lng = widget.currentLng;
      // For other members, pass target_user_id
      final targetUserId = widget.isSelf ? null : widget.data.userId;

      await SupabaseService.instance.createAlert(
        groupId: groupId,
        kind: 'ok_check',
        lat: lat,
        lng: lng,
        targetUserId: targetUserId,
      );

      if (mounted) {
        _showSnack(
          widget.isSelf
              ? '✅ Señal "Todo ok" enviada al grupo'
              : '✅ Señal enviada a ${widget.data.displayName}',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Error al enviar señal', isError: true);
    }
  }

  Future<void> _enviarMensaje() async {
    if (widget.isSelf) {
      _showSnack('Mensajería aún no disponible');
      return;
    }

    final phone = widget.data.phone;
    if (phone == null || phone.trim().isEmpty) {
      _showSnack('No hay un medio de contacto disponible para este miembro.');
      return;
    }

    // Normalize phone: remove spaces, dashes, parentheses
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Contactar a ${widget.data.displayName}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.sms_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
              title: const Text('SMS'),
              subtitle: Text(phone),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri(scheme: 'sms', path: normalized);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (mounted) {
                    _showSnack('No se pudo abrir SMS', isError: true);
                  }
                }
              },
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Color(0xFF25D366),
                  size: 20,
                ),
              ),
              title: const Text('WhatsApp'),
              subtitle: Text(phone),
              onTap: () async {
                Navigator.pop(ctx);
                // WhatsApp deep link: remove leading + for wa.me
                final waNumber = normalized.startsWith('+')
                    ? normalized.substring(1)
                    : normalized;
                final uri = Uri.parse('https://wa.me/$waNumber');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    _showSnack('No se pudo abrir WhatsApp', isError: true);
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarSitio() async {
    final lat = widget.currentLat;
    final lng = widget.currentLng;

    if (lat == null || lng == null) {
      _showSnack('Ubicación no disponible aún');
      return;
    }

    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    final name = widget.isSelf
        ? 'Mi ubicación actual'
        : 'Ubicación de ${widget.data.displayName}';
    final text =
        '📍 $name:\n$mapsUrl\n\nLat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) _showSnack('Ubicación copiada al portapapeles');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.sos : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarColor = _parseColor(widget.data.avatarColorHex);
    final displayColor = widget.isSelf ? AppTheme.primary : avatarColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.40,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ──────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: widget.isSelf ? _changePhoto : null,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: displayColor,
                            border: Border.all(
                              color: AppTheme.primaryContainer,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: displayColor.withAlpha(80),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _uploadingPhoto
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : (_localPhotoUrl != null &&
                                        _localPhotoUrl!.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          _localPhotoUrl!,
                                          fit: BoxFit.cover,
                                          width: 64,
                                          height: 64,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(
                                              _initial,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 26,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          _initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      )),
                        ),
                        // Camera icon (self only)
                        if (widget.isSelf)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        // "Tú" badge (self) or nothing (other)
                        if (widget.isSelf)
                          Positioned(
                            top: -4,
                            left: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Tú',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        if (widget.groupName != null)
                          Row(
                            children: [
                              Icon(
                                Icons.shield_rounded,
                                size: 12,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.groupName!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 3),
                        if (widget.lastLocationUpdate != null) ...[
                          Text(
                            'Actualizado: ${_formatTime(widget.lastLocationUpdate!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ] else if (widget.data.updatedAt != null) ...[
                          Text(
                            'Actualizado: ${_formatTime(widget.data.updatedAt!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        if (widget.isSelf) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _changePhoto,
                            child: Text(
                              'Cambiar foto',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Status chips ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatusChip(
                      label: 'Estado',
                      value: _movementLabel,
                      icon: _movementIcon,
                      color: _movementColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusChip(
                      label: 'Batería',
                      value: widget.data.battery != null
                          ? '${widget.data.battery}%'
                          : 'N/D',
                      icon: Icons.battery_4_bar_rounded,
                      color: widget.data.battery != null
                          ? (widget.data.battery! > 20
                                ? AppTheme.success
                                : AppTheme.sos)
                          : AppTheme.statusOffline,
                    ),
                  ),
                ],
              ),

              // Activity chip
              const SizedBox(height: 8),
              _StatusChip(
                label: 'Actividad',
                value: _activityLabel,
                icon: Icons.local_activity_rounded,
                color: widget.data.activityState == PersonActivityState.normal
                    ? AppTheme.statusOffline
                    : AppTheme.success,
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ── Action list ──────────────────────────────────────────────
              _buildActionList(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionList(ThemeData theme) {
    if (widget.isSelf) {
      return Column(
        children: [
          _ActionTile(
            icon: Icons.person_search_rounded,
            label: 'Consultar / editar ficha',
            sublabel: 'Ver y editar tu perfil',
            isAvailable: true,
            onTap: _consultarFicha,
          ),
          _ActionTile(
            icon: Icons.route_rounded,
            label: 'Últimos movimientos',
            sublabel: 'Ver historial de ubicaciones',
            isAvailable: true,
            onTap: _ultimosMovimientos,
          ),
          const Divider(height: 16),
          _ActionTile(
            icon: Icons.check_circle_outline_rounded,
            label: '¿Todo ok?',
            sublabel: 'Enviar señal de check-in al grupo',
            isAvailable: widget.groupId != null,
            onTap: _todoOk,
          ),
          _ActionTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Enviar mensaje',
            sublabel: 'Mensajería aún no disponible',
            isAvailable: false,
            onTap: null,
          ),
          _ActionTile(
            icon: Icons.share_location_rounded,
            label: 'Enviar sitio',
            sublabel: widget.currentLat != null
                ? 'Compartir ubicación actual'
                : 'Ubicación no disponible aún',
            isAvailable: widget.currentLat != null,
            onTap: _enviarSitio,
          ),
          const Divider(height: 16),
          _ActionTile(
            icon: Icons.groups_rounded,
            label: 'Quedada / Convoy',
            sublabel: 'Módulo aún no disponible',
            isAvailable: false,
            onTap: null,
          ),
        ],
      );
    } else {
      // Other member actions
      final hasPhone =
          widget.data.phone != null && widget.data.phone!.trim().isNotEmpty;
      return Column(
        children: [
          _ActionTile(
            icon: Icons.person_search_rounded,
            label: 'Consultar ficha',
            sublabel: 'Ver perfil del miembro',
            isAvailable: true,
            onTap: _consultarFicha,
          ),
          _ActionTile(
            icon: Icons.route_rounded,
            label: 'Últimos movimientos',
            sublabel: 'Ver historial de ubicaciones',
            isAvailable: true,
            onTap: _ultimosMovimientos,
          ),
          const Divider(height: 16),
          _ActionTile(
            icon: Icons.check_circle_outline_rounded,
            label: '¿Todo bien?',
            sublabel: widget.groupId != null
                ? 'Enviar señal a ${widget.data.displayName}'
                : 'Selecciona un grupo primero',
            isAvailable: widget.groupId != null,
            onTap: _todoOk,
          ),
          _ActionTile(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Enviar mensaje',
            sublabel: hasPhone
                ? 'SMS o WhatsApp'
                : 'No hay contacto disponible para este miembro',
            isAvailable: hasPhone,
            onTap: hasPhone ? _enviarMensaje : null,
          ),
          _ActionTile(
            icon: Icons.share_location_rounded,
            label: 'Enviar sitio',
            sublabel: widget.currentLat != null
                ? 'Compartir ubicación actual'
                : 'Ubicación no disponible aún',
            isAvailable: widget.currentLat != null,
            onTap: _enviarSitio,
          ),
        ],
      );
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} días';
  }
}

// ─── STATUS CHIP ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── ACTION TILE ─────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isAvailable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: isAvailable ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isAvailable
                    ? AppTheme.primaryContainer
                    : AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isAvailable
                    ? AppTheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isAvailable
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isAvailable
                  ? Icons.chevron_right_rounded
                  : Icons.lock_outline_rounded,
              size: 18,
              color: isAvailable
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EDIT PROFILE SHEET ───────────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final String displayName;
  final VoidCallback? onSaved;

  const _EditProfileSheet({required this.displayName, this.onSaved});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre no puede estar vacío');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('No autenticado');
      await SupabaseService.instance.updateProfile(
        userId: userId,
        displayName: name,
      );
      if (mounted) {
        widget.onSaved?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Error al guardar: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(
            'Editar perfil',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nombre visible',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _error,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── MEMBER PROFILE SHEET (read-only) ────────────────────────────────────────

class _MemberProfileSheet extends StatelessWidget {
  final PersonMapData data;
  const _MemberProfileSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color avatarColor;
    try {
      final h = data.avatarColorHex.replaceAll('#', '');
      avatarColor = Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      avatarColor = AppTheme.primary;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor,
                  border: Border.all(
                    color: AppTheme.primaryContainer,
                    width: 2,
                  ),
                ),
                child: data.avatarUrl != null && data.avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          data.avatarUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          data.displayName.isNotEmpty
                              ? data.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (data.phone != null && data.phone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data.phone!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── MOVEMENT HISTORY SHEET ───────────────────────────────────────────────────

class _MovementHistorySheet extends StatelessWidget {
  final List<Map<String, dynamic>> locations;
  const _MovementHistorySheet({required this.locations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Últimos movimientos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (locations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.route_rounded,
                    size: 48,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aún no hay historial de movimientos disponible.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                itemCount: locations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final loc = locations[i];
                  final lat = (loc['lat'] as num?)?.toDouble();
                  final lng = (loc['lng'] as num?)?.toDouble();
                  final updatedAt = loc['updated_at'] as String?;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                    ),
                    title: Text(
                      lat != null && lng != null
                          ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                          : 'Coordenadas no disponibles',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                    subtitle: updatedAt != null
                        ? Text(
                            _formatDateTime(updatedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
