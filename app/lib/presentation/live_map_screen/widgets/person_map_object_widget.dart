import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PersonMapObject — Sentinel reusable person marker for ALL group members
/// ═══════════════════════════════════════════════════════════════════════════
///
/// ANCHOR GEOMETRY (IMMUTABLE):
///   The geographic coordinate maps to the EXACT CENTER of the geolocation
///   circle. Enforced by:
///     1. Overlay Positioned: left = screenX - kAnchorX, top = screenY - kAnchorY
///     2. Geolocation circle always centered in the fixed bounding box
///     3. Info capsule positioned ABOVE via Stack/Positioned — never shifts center
///     4. Transform.scale uses alignment = Alignment.center so the geo-core
///        center pixel stays coincident with the LatLng at every scale value.
///
/// EXPLICIT CONSTANTS (never change at runtime):
///   kMarkerWidth  = 120.0
///   kMarkerHeight = 80.0
///   kGeoCoreDiameter = 40.0
///   kAnchorX = 60.0  (center of box)
///   kAnchorY = 40.0  (center of box)
///
/// Overlay positioning MUST use:
///   left: screenPos.dx - PersonMapObjectWidget.kAnchorX
///   top:  screenPos.dy - PersonMapObjectWidget.kAnchorY
///   (centers the geo-core on the Mapbox screen coordinate)
///
/// ZOOM-RESPONSIVE SCALE:
///   Visual scale is derived from currentZoom via smooth interpolation.
///   Scale is applied with Transform.scale(alignment: Alignment.center)
///   so the geo-core center pixel never moves.
///   Self marker gets a slight bonus (+0.08) over other members.
///
/// PROGRESSIVE CAPSULE:
///   zoom < 16.0  → photo only
///   16.0–17.5    → photo + name
///   > 17.5       → photo + address/name + battery
/// ═══════════════════════════════════════════════════════════════════════════

/// Movement state derived from real GPS data only.
enum PersonMovementState {
  moving, // speed > 0.5 m/s
  stopped, // speed <= 0.5 m/s
  unknown, // no speed data available
}

/// Activity context backed by real records.
enum PersonActivityState {
  normal, // no active route/meeting/convoy
  route, // on an active route (future)
  meeting, // in a meeting/quedada (future)
  convoy, // in a convoy (future)
}

/// Data model for a person on the map.
class PersonMapData {
  final String userId;
  final String displayName;
  final String avatarColorHex;
  final String? avatarUrl;
  final double lat;
  final double lng;
  final DateTime? updatedAt;
  final int? battery;
  final PersonMovementState movementState;
  final PersonActivityState activityState;
  final String? phone;
  final String? shortAddress;
  // Future fields — null until implemented
  final String? routeState;
  final String? meetingState;
  final String? convoyState;

  const PersonMapData({
    required this.userId,
    required this.displayName,
    required this.avatarColorHex,
    this.avatarUrl,
    required this.lat,
    required this.lng,
    this.updatedAt,
    this.battery,
    this.movementState = PersonMovementState.unknown,
    this.activityState = PersonActivityState.normal,
    this.phone,
    this.shortAddress,
    this.routeState,
    this.meetingState,
    this.convoyState,
  });
}

/// Capsule detail level derived from zoom.
enum _CapsuleLevel {
  photoOnly, // zoom < 16.0
  photoName, // 16.0 – 17.5
  full, // > 17.5
}

class PersonMapObjectWidget extends StatelessWidget {
  // ── EXPLICIT ANCHOR GEOMETRY (IMMUTABLE) ───────────────────────────────
  static const double kMarkerWidth = 120.0;
  static const double kMarkerHeight = 80.0;
  static const double kGeoCoreDiameter = 40.0;
  static const double kGeoCoreRadius = kGeoCoreDiameter / 2;
  static const double kAnchorX = kMarkerWidth / 2; // = 60.0
  static const double kAnchorY = kMarkerHeight / 2; // = 40.0

  // ── INFO CAPSULE GEOMETRY (FIXED) ──────────────────────────────────────
  static const double kCapsuleHeight = 30.0;

  // ── ZOOM SCALE BREAKPOINTS ─────────────────────────────────────────────
  // Smooth interpolation between these anchor points.
  // Self gets +0.08 bonus on top of the computed scale.
  static const List<_ZoomScalePoint> _scalePoints = [
    _ZoomScalePoint(zoom: 14.0, scale: 0.65),
    _ZoomScalePoint(zoom: 15.5, scale: 0.75),
    _ZoomScalePoint(zoom: 16.5, scale: 0.90),
    _ZoomScalePoint(zoom: 17.5, scale: 1.05),
    _ZoomScalePoint(zoom: 18.2, scale: 1.20),
    _ZoomScalePoint(zoom: 19.0, scale: 1.35),
    _ZoomScalePoint(zoom: 20.0, scale: 1.45),
  ];

  static const double _minScale = 0.60;
  static const double _maxScale = 1.45;
  static const double _selfBonus = 0.08;

  // ── INPUTS ─────────────────────────────────────────────────────────────
  final PersonMapData data;
  final bool isSelf;
  final bool isSelected;

  /// Current map zoom level — drives visual scale and capsule detail.
  final double currentZoom;

  const PersonMapObjectWidget({
    required this.data,
    required this.isSelf,
    required this.currentZoom,
    this.isSelected = false,
    super.key,
  });

  // ── SCALE COMPUTATION ──────────────────────────────────────────────────

  /// Smooth linear interpolation between the defined zoom→scale breakpoints.
  /// Clamped to [_minScale, _maxScale].
  double _computeScale() {
    double base;
    if (currentZoom <= _scalePoints.first.zoom) {
      base = _scalePoints.first.scale;
    } else if (currentZoom >= _scalePoints.last.zoom) {
      base = _scalePoints.last.scale;
    } else {
      // Find surrounding segment and lerp
      for (int i = 0; i < _scalePoints.length - 1; i++) {
        final lo = _scalePoints[i];
        final hi = _scalePoints[i + 1];
        if (currentZoom >= lo.zoom && currentZoom <= hi.zoom) {
          final t = (currentZoom - lo.zoom) / (hi.zoom - lo.zoom);
          base = lo.scale + t * (hi.scale - lo.scale);
          break;
        }
      }
      // Fallback (should never reach here)
      base = 1.0;
    }
    final bonus = isSelf ? _selfBonus : 0.0;
    return (base + bonus).clamp(_minScale, _maxScale + _selfBonus);
  }

  // ── CAPSULE LEVEL ──────────────────────────────────────────────────────

  _CapsuleLevel get _capsuleLevel {
    if (currentZoom < 16.0) return _CapsuleLevel.photoOnly;
    if (currentZoom < 17.5) return _CapsuleLevel.photoName;
    return _CapsuleLevel.full;
  }

  // ── CAPSULE WIDTH ──────────────────────────────────────────────────────

  double get _capsuleWidth {
    switch (_capsuleLevel) {
      case _CapsuleLevel.photoOnly:
        return kCapsuleHeight; // square — photo only
      case _CapsuleLevel.photoName:
        return 64.0;
      case _CapsuleLevel.full:
        return 80.0;
    }
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _parseColor(data.avatarColorHex);
    final scale = _computeScale();

    // The outer SizedBox is FIXED — it defines the Marker bounding box.
    // Transform.scale is applied INSIDE with alignment = Alignment.center,
    // which means the center pixel of the box (= kAnchorX, kAnchorY =
    // the geo-core center) stays fixed while the visual content scales.
    return SizedBox(
      width: kMarkerWidth,
      height: kMarkerHeight,
      child: Transform.scale(
        scale: scale,
        // Alignment.center = scale around the center of the SizedBox,
        // which is exactly kAnchorX=60, kAnchorY=40 — the geo-core center.
        // The LatLng anchor pixel never moves.
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Geolocation circle — centered at (kAnchorX, kAnchorY) ──────
            Positioned(
              left: kAnchorX - kGeoCoreRadius,
              top: kAnchorY - kGeoCoreRadius,
              child: _buildGeoCore(avatarColor),
            ),

            // ── Info capsule — ABOVE and to the LEFT of geo circle ──────────
            // ALWAYS rendered. Photo is always visible.
            // Stack-positioned: does NOT push the geo circle.
            // clipBehavior: Clip.none allows it to extend beyond box.
            Positioned(
              top: kAnchorY - kGeoCoreRadius - kCapsuleHeight - 4.0,
              left: kAnchorX - kGeoCoreRadius - 4.0,
              child: _buildInfoCapsule(avatarColor),
            ),

            // ── "Tú" badge for self ─────────────────────────────────────────
            if (isSelf)
              Positioned(
                bottom: kMarkerHeight - kAnchorY - kGeoCoreRadius - 2,
                left: kAnchorX - kGeoCoreRadius,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    'Tú',
                    style: GoogleFonts.inter(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Sentinel geolocation symbol: outer ring + inner dot.
  /// Center = geographic anchor. Never changes position.
  Widget _buildGeoCore(Color avatarColor) {
    final coreColor = isSelf ? AppTheme.primary : avatarColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: kGeoCoreDiameter,
      height: kGeoCoreDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: coreColor,
        border: Border.all(color: Colors.white, width: isSelected ? 3.0 : 2.0),
        boxShadow: [
          BoxShadow(
            color: coreColor.withAlpha(isSelected ? 160 : 90),
            blurRadius: isSelected ? 14.0 : 8.0,
            spreadRadius: isSelected ? 3.0 : 1.0,
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            Container(
              width: kGeoCoreDiameter * 0.55,
              height: kGeoCoreDiameter * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            // Inner dot
            Container(
              width: kGeoCoreDiameter * 0.22,
              height: kGeoCoreDiameter * 0.22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Progressive info capsule based on zoom level.
  ///
  /// photoOnly  → square capsule with photo only
  /// photoName  → photo + first name
  /// full       → photo + address/name + battery
  ///
  /// ALWAYS VISIBLE — even when address and battery are null.
  /// Photo is ALWAYS shown (real photo or neutral avatar fallback).
  Widget _buildInfoCapsule(Color avatarColor) {
    final coreColor = isSelf ? AppTheme.primary : avatarColor;
    final level = _capsuleLevel;
    final width = _capsuleWidth;

    return Container(
      width: width,
      height: kCapsuleHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: coreColor.withAlpha(100), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 6.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: level == _CapsuleLevel.photoOnly
            ? _buildCapsulePhoto(coreColor, kCapsuleHeight)
            : Row(
                children: [
                  // ── Profile photo — ALWAYS visible ─────────────────────
                  SizedBox(
                    width: 30.0,
                    height: kCapsuleHeight,
                    child: _buildCapsulePhoto(coreColor, 30.0),
                  ),
                  // ── Text area ──────────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3.0,
                        vertical: 2.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Primary line
                          Text(
                            _primaryLabel(level),
                            style: GoogleFonts.inter(
                              fontSize: 7.0,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF333333),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Battery line: only in full level when data exists
                          if (level == _CapsuleLevel.full &&
                              data.battery != null)
                            Text(
                              '🔋 ${data.battery}%',
                              style: GoogleFonts.inter(
                                fontSize: 7.0,
                                fontWeight: FontWeight.w500,
                                color: _batteryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCapsulePhoto(Color coreColor, double size) {
    final url = data.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRect(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoFallback(coreColor, size),
        ),
      );
    }
    return _photoFallback(coreColor, size);
  }

  Widget _photoFallback(Color coreColor, double size) {
    return Container(
      width: size,
      height: size,
      color: coreColor.withAlpha(200),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }

  /// Primary label for the capsule text area.
  /// photoName level: first name only.
  /// full level: short address if available, else first name.
  String _primaryLabel(_CapsuleLevel level) {
    if (level == _CapsuleLevel.full) {
      if (data.shortAddress != null && data.shortAddress!.isNotEmpty) {
        final addr = data.shortAddress!;
        return addr.length > 10 ? '${addr.substring(0, 9)}…' : addr;
      }
    }
    // Name fallback for both photoName and full
    final name = data.displayName;
    if (name.isEmpty) return '—';
    final first = name.split(' ').first;
    return first.length > 8 ? '${first.substring(0, 7)}…' : first;
  }

  Color get _batteryColor {
    if (data.battery == null) return const Color(0xFF999999);
    if (data.battery! <= 20) return const Color(0xFFE53935);
    if (data.battery! <= 50) return const Color(0xFFF57C00);
    return const Color(0xFF388E3C);
  }
}

/// Immutable zoom→scale anchor point for interpolation.
class _ZoomScalePoint {
  final double zoom;
  final double scale;
  const _ZoomScalePoint({required this.zoom, required this.scale});
}
