import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

/// Real own-user profile panel.
///
/// REAL actions:
///   - Consultar ficha (editable profile)
///   - Últimos movimientos (real or "no history yet")
///   - ¿Todo ok? (uses existing alert_events infrastructure)
///   - Enviar sitio (native share with real coordinates)
///   - Profile photo upload to Supabase Storage avatars/{userId}/profile
///
/// CLEARLY UNAVAILABLE:
///   - Enviar mensaje
///   - Quedada / Convoy
class OwnUserDetailSheetWidget extends StatefulWidget {
  final String displayName;
  final String avatarColorHex;
  final String? photoUrl;
  final String? addressLabel;
  final int? batteryPercent;
  final String? groupName;
  final String? groupId;
  final double? currentLat;
  final double? currentLng;
  final double? currentSpeed; // m/s from GPS
  final DateTime? lastLocationUpdate;
  final VoidCallback? onProfileUpdated;

  const OwnUserDetailSheetWidget({
    required this.displayName,
    required this.avatarColorHex,
    this.photoUrl,
    this.addressLabel,
    this.batteryPercent,
    this.groupName,
    this.groupId,
    this.currentLat,
    this.currentLng,
    this.currentSpeed,
    this.lastLocationUpdate,
    this.onProfileUpdated,
    super.key,
  });

  @override
  State<OwnUserDetailSheetWidget> createState() =>
      _OwnUserDetailSheetWidgetState();
}

class _OwnUserDetailSheetWidgetState extends State<OwnUserDetailSheetWidget> {
  bool _uploadingPhoto = false;
  String? _localPhotoUrl; // updated after upload

  @override
  void initState() {
    super.initState();
    _localPhotoUrl = widget.photoUrl;
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  String get _initial =>
      widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : 'S';

  /// Derive movement state from GPS speed.
  /// speed is in m/s. >0.5 m/s (~1.8 km/h) = MOVING.
  _MovementState get _movementState {
    if (widget.currentSpeed == null) return _MovementState.unknown;
    if (widget.currentSpeed! > 0.5) return _MovementState.moving;
    return _MovementState.stopped;
  }

  String get _movementLabel {
    switch (_movementState) {
      case _MovementState.moving:
        return 'En movimiento';
      case _MovementState.stopped:
        return 'Parado';
      case _MovementState.unknown:
        return 'Desconocido';
    }
  }

  IconData get _movementIcon {
    switch (_movementState) {
      case _MovementState.moving:
        return Icons.directions_walk_rounded;
      case _MovementState.stopped:
        return Icons.pause_circle_outline_rounded;
      case _MovementState.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get _movementColor {
    switch (_movementState) {
      case _MovementState.moving:
        return AppTheme.success;
      case _MovementState.stopped:
        return AppTheme.warning;
      case _MovementState.unknown:
        return AppTheme.statusOffline;
    }
  }

  // ─── PHOTO UPLOAD ────────────────────────────────────────────────────────

  Future<void> _changePhoto() async {
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
      // Normalize extension — default to jpg for unknown types
      final rawExt = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final ext = ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(rawExt)
          ? rawExt
          : 'jpg';
      // Storage path: avatars/{userId}/profile.{ext}
      // The folder name MUST equal the userId for RLS policy to pass
      final storagePath = '$userId/profile.$ext';

      debugPrint('[Photo] Uploading to bucket=avatars path=$storagePath');

      // Upload to Supabase Storage bucket "avatars"
      // upsert: true replaces existing file
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );

      debugPrint('[Photo] Upload succeeded, getting public URL');

      // Get public URL (bucket is public)
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      debugPrint('[Photo] Public URL: $publicUrl');

      // Save to profiles.avatar_url
      // NOTE: avatar_url column was added via migration 20260908080000
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
      // Capture and display the EXACT error — do not assume Preview Mode
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
    Navigator.pop(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        displayName: widget.displayName,
        onSaved: () => widget.onProfileUpdated?.call(),
      ),
    );
  }

  Future<void> _ultimosMovimientos() async {
    // Check if any location history exists
    final userId = SupabaseService.instance.currentUserId;
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

      if (mounted) Navigator.pop(context); // dismiss loader

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
            const Text('¿Todo ok?'),
          ],
        ),
        content: const Text(
          'Se enviará una señal de "Todo ok" a tu grupo activo.',
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
      await SupabaseService.instance.createAlert(
        groupId: groupId,
        kind: 'ok_check',
        lat: widget.currentLat,
        lng: widget.currentLng,
      );
      if (mounted) _showSnack('✅ Señal "Todo ok" enviada al grupo');
    } catch (e) {
      if (mounted) _showSnack('Error al enviar señal', isError: true);
    }
  }

  Future<void> _enviarSitio() async {
    final lat = widget.currentLat;
    final lng = widget.currentLng;

    if (lat == null || lng == null) {
      _showSnack('Ubicación no disponible aún');
      return;
    }

    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    final text =
        '📍 Mi ubicación actual:\n$mapsUrl\n\nLat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';

    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      // Fallback: copy to clipboard
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
    final avatarColor = _parseColor(widget.avatarColorHex);

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.40,
      maxChildSize: 0.85,
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

              // ── Header ────────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tappable avatar with photo upload
                  GestureDetector(
                    onTap: _changePhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: avatarColor,
                            border: Border.all(
                              color: AppTheme.primaryContainer,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: avatarColor.withAlpha(80),
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
                        // Camera icon overlay
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
                        // "Tú" badge
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
                          widget.displayName,
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
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.addressLabel ??
                                    'Ubicación no disponible',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (widget.lastLocationUpdate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Actualizado: ${_formatTime(widget.lastLocationUpdate!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
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
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Status chips ───────────────────────────────────────────────
              _buildStatusRow(theme),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ── Action list ────────────────────────────────────────────────
              _buildActionList(context, theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(ThemeData theme) {
    return Row(
      children: [
        // Movement state — REAL from GPS speed
        Expanded(
          child: _StatusChip(
            label: 'Estado',
            value: _movementLabel,
            icon: _movementIcon,
            color: _movementColor,
          ),
        ),
        const SizedBox(width: 8),
        // Battery — REAL if available
        Expanded(
          child: _StatusChip(
            label: 'Batería',
            value: widget.batteryPercent != null
                ? '${widget.batteryPercent}%'
                : 'N/D',
            icon: Icons.battery_4_bar_rounded,
            color: widget.batteryPercent != null
                ? (widget.batteryPercent! > 20
                      ? AppTheme.success
                      : AppTheme.sos)
                : AppTheme.statusOffline,
          ),
        ),
      ],
    );
  }

  Widget _buildActionList(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        // REAL: Consultar ficha
        _ActionTile(
          icon: Icons.person_search_rounded,
          label: 'Consultar ficha',
          sublabel: 'Ver y editar tu perfil',
          isAvailable: true,
          onTap: _consultarFicha,
        ),
        // REAL: Últimos movimientos
        _ActionTile(
          icon: Icons.route_rounded,
          label: 'Últimos movimientos',
          sublabel: 'Ver historial de ubicaciones',
          isAvailable: true,
          onTap: _ultimosMovimientos,
        ),
        const Divider(height: 16),
        // REAL: ¿Todo ok?
        _ActionTile(
          icon: Icons.check_circle_outline_rounded,
          label: '¿Todo ok?',
          sublabel: 'Enviar señal de check-in al grupo',
          isAvailable: widget.groupId != null,
          onTap: _todoOk,
        ),
        // UNAVAILABLE: Enviar mensaje
        _ActionTile(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Enviar mensaje',
          sublabel: 'Mensajería aún no disponible',
          isAvailable: false,
          onTap: null,
        ),
        // REAL: Enviar sitio
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
        // UNAVAILABLE: Quedada / Convoy
        _ActionTile(
          icon: Icons.groups_rounded,
          label: 'Quedada / Convoy',
          sublabel: 'Módulo aún no disponible',
          isAvailable: false,
          onTap: null,
        ),
      ],
    );
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

enum _MovementState { moving, stopped, unknown }

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
