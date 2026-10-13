import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// OwnUserMarkerWidget — Sentinel geolocation symbol
/// ═══════════════════════════════════════════════════════════════════════════
///
/// ANCHOR GEOMETRY (IMMUTABLE):
///   The geographic coordinate maps to the EXACT CENTER of the geolocation
///   circle. This is enforced by:
///     1. Marker.alignment = Alignment.center  (in live_map_screen.dart)
///     2. The geolocation circle is always centered in the fixed bounding box
///     3. The info capsule is positioned ABOVE and to the RIGHT using a Stack
///        with Positioned — it NEVER shifts the circle center
///
/// EXPLICIT CONSTANTS (never change at runtime):
///   kMarkerWidth  = total bounding box width
///   kMarkerHeight = total bounding box height
///   kGeoCoreDiameter = diameter of the geolocation circle
///   kAnchorX = kMarkerWidth / 2   (center of box = center of geo circle)
///   kAnchorY = kMarkerHeight / 2  (center of box = center of geo circle)
///
/// The Marker in flutter_map must use:
///   width:     OwnUserMarkerWidget.kMarkerWidth
///   height:    OwnUserMarkerWidget.kMarkerHeight
///   alignment: Alignment.center   ← CRITICAL: center of circle = LatLng
///
/// INFO CAPSULE:
///   Positioned above-right of the geo circle.
///   Fixed size. Text is ellipsized. NEVER expands the bounding box.
///   Does NOT influence the geographic anchor.
/// ═══════════════════════════════════════════════════════════════════════════
class OwnUserMarkerWidget extends StatelessWidget {
  // ── EXPLICIT ANCHOR GEOMETRY (IMMUTABLE CONSTANTS) ─────────────────────
  /// Total bounding box width. NEVER changes.
  static const double kMarkerWidth = 120.0;

  /// Total bounding box height. NEVER changes.
  static const double kMarkerHeight = 80.0;

  /// Diameter of the Sentinel geolocation circle. NEVER changes.
  static const double kGeoCoreDiameter = 40.0;

  /// Radius of the geolocation circle.
  static const double kGeoCoreRadius = kGeoCoreDiameter / 2;

  /// X pixel of the geographic anchor within the bounding box.
  /// = center of the geolocation circle = center of the bounding box.
  static const double kAnchorX = kMarkerWidth / 2;

  /// Y pixel of the geographic anchor within the bounding box.
  /// = center of the geolocation circle = center of the bounding box.
  static const double kAnchorY = kMarkerHeight / 2;

  // ── INFO CAPSULE GEOMETRY (FIXED, NEVER CHANGES) ───────────────────────
  /// Capsule width. Fixed. Content is clipped/ellipsized.
  static const double kCapsuleWidth = 72.0;

  /// Capsule height. Fixed.
  static const double kCapsuleHeight = 30.0;

  // ── INPUTS ──────────────────────────────────────────────────────────────
  final String displayName;
  final String avatarColorHex;
  final String? photoUrl;
  final String? addressLabel;
  final int? batteryPercent;
  final bool isSelected;

  const OwnUserMarkerWidget({
    required this.displayName,
    required this.avatarColorHex,
    this.photoUrl,
    this.addressLabel,
    this.batteryPercent,
    this.isSelected = false,
    super.key,
  });

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
    final avatarColor = _parseColor(avatarColorHex);

    // ── FIXED BOUNDING BOX ─────────────────────────────────────────────────
    // Alignment.center on the Marker means the CENTER of this SizedBox
    // maps to the geographic coordinate. The geolocation circle is always
    // centered in this box. Nothing below changes the box dimensions.
    return SizedBox(
      width: kMarkerWidth,
      height: kMarkerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Geolocation circle — centered at (kAnchorX, kAnchorY) ────────
          // left = kAnchorX - kGeoCoreRadius = center of box - radius
          // top  = kAnchorY - kGeoCoreRadius = center of box - radius
          Positioned(
            left: kAnchorX - kGeoCoreRadius,
            top: kAnchorY - kGeoCoreRadius,
            child: _buildGeoCore(avatarColor),
          ),

          // ── Info capsule — ABOVE and to the RIGHT of the geo circle ──────
          // Positioned so it floats above-right.
          // CRITICAL: This is Stack-positioned. It does NOT push the geo circle.
          // The bounding box is fixed — capsule may extend beyond right edge
          // (clipBehavior: Clip.none allows this without affecting anchor).
          Positioned(
            top: kAnchorY - kGeoCoreRadius - kCapsuleHeight - 4.0,
            left: kAnchorX - kGeoCoreRadius - 4.0,
            child: _buildInfoCapsule(avatarColor),
          ),
        ],
      ),
    );
  }

  /// Sentinel geolocation symbol: outer ring + inner dot.
  /// This is the geographic anchor. Its center = kAnchorX, kAnchorY.
  /// Clean circular symbol — no letter, no teardrop, no pin tail.
  Widget _buildGeoCore(Color avatarColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: kGeoCoreDiameter,
      height: kGeoCoreDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColor,
        border: Border.all(color: Colors.white, width: isSelected ? 3.0 : 2.0),
        boxShadow: [
          BoxShadow(
            color: avatarColor.withAlpha(isSelected ? 160 : 90),
            blurRadius: isSelected ? 14.0 : 8.0,
            spreadRadius: isSelected ? 3.0 : 1.0,
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring (geolocation symbol)
            Container(
              width: kGeoCoreDiameter * 0.55,
              height: kGeoCoreDiameter * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
            // Inner dot (geolocation symbol)
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

  /// Compact info capsule: [ photo | address | battery ]
  /// Fixed size. Text is ellipsized. NEVER expands the bounding box.
  Widget _buildInfoCapsule(Color avatarColor) {
    return Container(
      width: kCapsuleWidth,
      height: kCapsuleHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: avatarColor.withAlpha(100), width: 1.0),
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
        child: Row(
          children: [
            // Photo (fixed 30px wide)
            SizedBox(
              width: 30.0,
              height: kCapsuleHeight,
              child: _buildCapsulePhoto(avatarColor),
            ),
            // Address + battery (fills remaining space, ellipsized)
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
                    Text(
                      _shortAddress,
                      style: GoogleFonts.inter(
                        fontSize: 7.0,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _batteryText,
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

  Widget _buildCapsulePhoto(Color avatarColor) {
    const photoSize = 30.0;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRect(
        child: Image.network(
          photoUrl!,
          width: photoSize,
          height: photoSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _neutralPhotoFallback(avatarColor, photoSize),
        ),
      );
    }
    return _neutralPhotoFallback(avatarColor, photoSize);
  }

  /// Neutral fallback: solid color background with a person icon.
  /// No letter, no initial — clean and recognizable.
  Widget _neutralPhotoFallback(Color avatarColor, double size) {
    return Container(
      width: size,
      height: size,
      color: avatarColor.withAlpha(200),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }

  String get _shortAddress {
    if (addressLabel == null || addressLabel!.isEmpty) return 'N/D';
    final parts = addressLabel!.split(',');
    return parts.first.trim();
  }

  String get _batteryText {
    if (batteryPercent == null) return '🔋 N/D';
    return '🔋 $batteryPercent%';
  }

  Color get _batteryColor {
    if (batteryPercent == null) return const Color(0xFF999999);
    if (batteryPercent! <= 20) return const Color(0xFFE53935);
    if (batteryPercent! <= 50) return const Color(0xFFF57C00);
    return const Color(0xFF388E3C);
  }
}
