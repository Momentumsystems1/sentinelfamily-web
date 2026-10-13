import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_fonts/google_fonts.dart';

import '../../../services/air_quality_service.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';

/// Tarjeta de calidad del aire (AQI europeo, Open-Meteo/CAMS).
/// Muestra la lectura de tu posición y de cada miembro con ubicación conocida.
/// Si algo falla, se oculta en silencio — nunca muestra datos inventados.
class AirQualityWidget extends StatefulWidget {
  const AirQualityWidget({super.key});

  @override
  State<AirQualityWidget> createState() => _AirQualityWidgetState();
}

class _AirQualityWidgetState extends State<AirQualityWidget> {
  bool _loading = true;
  List<_AirRow> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1) Mi posición (la mejor disponible; se omite si no hay permiso)
      final List<_AirRow> rows = [];
      final List<List<double>> points = [];

      try {
        final pos = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.low,
            timeLimit: Duration(seconds: 6),
          ),
        );
        points.add([pos.latitude, pos.longitude]);
        rows.add(_AirRow(label: 'Mi posición', pointIndex: 0, isMe: true));
      } catch (_) {
        // Sin permiso o sin GPS: seguimos con los miembros
      }

      // 2) Ubicaciones de los miembros de mis círculos
      final groups = await SupabaseService.instance.getMyGroups();
      final seen = <String>{};
      for (final g in groups) {
        final gid = g['id']?.toString();
        if (gid == null || seen.contains(gid)) continue;
        seen.add(gid);
        final locations = await SupabaseService.instance.getGroupLocations(gid);
        for (final loc in locations) {
          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final profile = loc['profiles'];
          String name = 'Miembro';
          if (profile is Map) {
            name =
                (profile['display_name'] as String?)?.trim().isNotEmpty == true
                ? profile['display_name'] as String
                : 'Miembro';
          }
          // Dedup por coordenadas redondeadas (misma persona en varios círculos)
          final key = '${lat.toStringAsFixed(3)}:${lng.toStringAsFixed(3)}';
          if (points.any(
            (p) =>
                p[0].toStringAsFixed(3) == lat.toStringAsFixed(3) &&
                p[1].toStringAsFixed(3) == lng.toStringAsFixed(3),
          )) {
            continue;
          }
          points.add([lat, lng]);
          rows.add(_AirRow(label: name, pointIndex: points.length - 1));
        }
      }

      if (points.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final readings = await AirQualityService.fetchBatch(points);
      final byIndex = <int, AirQualityReading>{};
      // fetchBatch devuelve en el mismo orden y compactado (sin aqi nulos)
      var ri = 0;
      for (var i = 0; i < points.length; i++) {
        if (ri < readings.length) {
          byIndex[i] = readings[ri];
          ri++;
        }
      }
      final finalRows = rows
          .where((r) => byIndex.containsKey(r.pointIndex))
          .map((r) => r..reading = byIndex[r.pointIndex])
          .toList();

      if (mounted) {
        setState(() {
          _rows = finalRows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo cargar la calidad del aire';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Consultando calidad del aire…',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null || _rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final worst = _rows
        .map((r) => r.reading!.aqi)
        .reduce((a, b) => a > b ? a : b);
    final worstReading = _rows.firstWhere((r) => r.reading!.aqi == worst);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.air_rounded,
                color: worstReading.reading!.levelColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Calidad del aire',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _load,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'AQI europeo · Open-Meteo / CAMS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ..._rows.map((row) {
            final r = row.reading!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: r.levelColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          r.levelLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: r.levelColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${r.aqi}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: r.levelColor,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (worstReading.reading!.advice != null) ...[
            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 16,
                  color: worstReading.reading!.levelColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    worstReading.reading!.advice!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AirRow {
  final String label;
  final int pointIndex;
  final bool isMe;
  AirQualityReading? reading;

  _AirRow({required this.label, required this.pointIndex, this.isMe = false});
}
