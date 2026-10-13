import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../services/group_change_notifier.dart';
import '../../theme/app_theme.dart';
import './map_renderer/sentinel_map_renderer.dart';
import './widgets/ghost_mode_chip_widget.dart';
import './widgets/map_group_selector_widget.dart';
import './widgets/member_avatar_strip_widget.dart';
import './widgets/person_map_object_widget.dart';
import './widgets/person_detail_sheet.dart';
import './widgets/sos_fab_widget.dart';

/// Camera mode for the map.
enum _CameraMode {
  /// User can freely pan/rotate/zoom. Camera does not follow GPS.
  free,

  /// Camera follows current user's GPS position with heading-based bearing.
  followMe,
}

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with WidgetsBindingObserver {
  bool _ghostMode = false;
  int? _ghostMinutesRemaining;
  String? _selectedGroupId;
  String _selectedGroupName = '';
  String? _selectedMemberId;
  bool _ownSheetOpen = false;

  // ── SentinelMapRenderer key — gives access to renderer state ─────────────
  final GlobalKey<SentinelMapRendererState> _rendererKey =
      GlobalKey<SentinelMapRendererState>();
  bool _mapReady = false;

  // ── Camera mode ───────────────────────────────────────────────────────────
  _CameraMode _cameraMode = _CameraMode.followMe;

  // ── Current camera state (tracked for overlay positioning) ───────────────
  double _currentZoom = 18.0;
  double _currentPitch = 50.0;
  double _currentBearing = 0.0;

  // ── Overlay positions: userId → screen offset ─────────────────────────────
  final Map<String, Offset> _overlayPositions = {};

  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _memberMaps = [];
  bool _isLoadingGroups = true;
  bool _isLoadingLocations = false;

  RealtimeChannel? _locationChannel;

  // ── GPS JITTER FILTER ─────────────────────────────────────────────────────
  static const double kAccuracyMultiplier = 1.5;
  static const double kMinMovementMeters = 8.0;
  static const double kMaxAcceptableAccuracyMeters = 50.0;

  geo.Position? _rawPosition;
  geo.Position? _displayPosition;

  bool _locationPermissionDenied = false;
  DateTime? _lastLocationWrite;
  DateTime? _lastLocationUpdate;
  static const Duration _locationThrottle = Duration(seconds: 15);

  StreamSubscription<geo.Position>? _positionSubscription;

  // Own user profile data
  String _ownDisplayName = 'Yo';
  String _ownAvatarColorHex = '#1B5E52';
  String? _ownPhotoUrl;

  bool _mapCenteredOnUser = false;

  // ── Overlay rebuild throttle ──────────────────────────────────────────────
  Timer? _overlayRebuildTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GroupChangeNotifier.instance.addListener(_onGroupsChanged);
    _loadOwnProfile();
    _loadGroups();
    _initLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GroupChangeNotifier.instance.removeListener(_onGroupsChanged);
    _locationChannel?.unsubscribe();
    _positionSubscription?.cancel();
    _overlayRebuildTimer?.cancel();
    super.dispose();
  }

  void _onGroupsChanged() {
    if (!mounted) return;
    // Consume pending active group id set by invitation acceptance
    final pendingId = GroupChangeNotifier.instance.pendingActiveGroupId;
    if (pendingId != null) {
      GroupChangeNotifier.instance.consumePendingActiveGroupId();
      _loadGroupsWithActiveId(pendingId);
    } else {
      _loadGroups();
    }
  }

  Future<void> _loadGroupsWithActiveId(String activeGroupId) async {
    if (!mounted) return;
    setState(() => _isLoadingGroups = true);
    try {
      final groups = await SupabaseService.instance.getMyGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _isLoadingGroups = false;
        if (groups.isEmpty) {
          _selectedGroupId = null;
          _selectedGroupName = '';
          _memberMaps = [];
        } else {
          final target = groups.firstWhere(
            (g) => g['id'] == activeGroupId,
            orElse: () => groups.first,
          );
          _selectedGroupId = target['id'] as String;
          _selectedGroupName = target['name'] as String;
        }
      });
      if (_selectedGroupId != null) {
        _loadLocations(_selectedGroupId!);
        _subscribeToLocations(_selectedGroupId!);
        final pos = _displayPosition ?? _rawPosition;
        if (pos != null) _writeLocation(pos);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadGroups();
    }
  }

  // ─── OWN PROFILE ──────────────────────────────────────────────────────────

  Future<void> _loadOwnProfile() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;
    try {
      final profile = await SupabaseService.instance.getProfile(userId);
      if (!mounted) return;
      setState(() {
        _ownDisplayName =
            profile?['display_name'] as String? ??
            SupabaseService.instance.currentUser?.email?.split('@').first ??
            'Yo';
        _ownAvatarColorHex = profile?['avatar_color'] as String? ?? '#1B5E52';
        _ownPhotoUrl = profile?['avatar_url'] as String?;
      });
      _scheduleOverlayRebuild();
    } catch (_) {}
  }

  // ─── LOCATION ─────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationPermissionDenied = true);
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          if (mounted) setState(() => _locationPermissionDenied = true);
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationPermissionDenied = true);
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      if (mounted) {
        _rawPosition = position;
        _displayPosition = position;
        setState(() {
          _mapCenteredOnUser = true;
          _currentZoom = 18.0;
        });
        _writeLocation(position);
        _flyToUser(position, animate: false);
      }

      _positionSubscription = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen(_onRawPositionReceived);
    } catch (e) {
      debugPrint('Location init error: $e');
      if (mounted) setState(() => _locationPermissionDenied = true);
    }
  }

  /// Called for every raw GPS fix.
  void _onRawPositionReceived(geo.Position rawPos) {
    if (!mounted) return;

    _rawPosition = rawPos;

    if (rawPos.accuracy > kMaxAcceptableAccuracyMeters) {
      _writeLocationThrottled(rawPos);
      return;
    }

    final current = _displayPosition;
    if (current != null) {
      final distanceMeters = _haversineDistance(
        current.latitude,
        current.longitude,
        rawPos.latitude,
        rawPos.longitude,
      );

      final threshold = math.max(
        rawPos.accuracy * kAccuracyMultiplier,
        kMinMovementMeters,
      );

      if (distanceMeters < threshold) {
        _writeLocationThrottled(rawPos);
        return;
      }
    }

    // Accept this fix
    setState(() => _displayPosition = rawPos);
    _writeLocationThrottled(rawPos);

    // Follow Me: update camera
    if (_cameraMode == _CameraMode.followMe && _mapReady) {
      _flyToUser(rawPos, animate: true);
    } else {
      _scheduleOverlayRebuild();
    }
  }

  /// Fly camera to user position with navigation pitch and heading.
  void _flyToUser(geo.Position pos, {required bool animate}) {
    final renderer = _rendererKey.currentState;
    if (renderer == null || !_mapReady) return;

    double bearing = _currentBearing;
    if (pos.speed > 0.5 && pos.heading >= 0) {
      bearing = pos.heading;
    }

    renderer.flyTo(
      lng: pos.longitude,
      lat: pos.latitude,
      zoom: 18.0,
      pitch: kIsWeb ? 0.0 : 50.0, // flutter_map is 2D
      bearing: bearing,
      durationMs: animate ? 800 : 1200,
    );
  }

  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;

  void _writeLocationThrottled(geo.Position pos) {
    final now = DateTime.now();
    if (_lastLocationWrite == null ||
        now.difference(_lastLocationWrite!) >= _locationThrottle) {
      _writeLocation(pos);
    }
  }

  Future<void> _writeLocation(geo.Position pos) async {
    final groupId = _selectedGroupId;
    if (groupId == null) return;
    _lastLocationWrite = DateTime.now();
    _lastLocationUpdate = _lastLocationWrite;
    await SupabaseService.instance.upsertLocation(
      groupId: groupId,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
    );
  }

  // ─── CAMERA CONTROLS ──────────────────────────────────────────────────────

  /// Center on Me — activates Follow Me mode.
  void _moveToMyLocation() {
    final pos = _displayPosition ?? _rawPosition;
    if (pos != null) {
      setState(() => _cameraMode = _CameraMode.followMe);
      _flyToUser(pos, animate: true);
    } else if (_locationPermissionDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Sentinel necesita acceso a tu ubicación para mostrarte en el mapa. Actívalo en Ajustes.',
          ),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Ajustes',
            textColor: Colors.white,
            onPressed: () => geo.Geolocator.openAppSettings(),
          ),
        ),
      );
    }
  }

  /// Ver grupo completo — explicit user action only. Exits Follow Me.
  void _fitAllMembers() {
    final renderer = _rendererKey.currentState;
    if (renderer == null || !_mapReady) return;

    setState(() => _cameraMode = _CameraMode.free);

    final coords = <(double, double)>[];

    final ownPos = _displayPosition ?? _rawPosition;
    if (ownPos != null) {
      coords.add((ownPos.latitude, ownPos.longitude));
    }

    for (final m in _memberMaps) {
      final lat = m['lat'] as double?;
      final lng = m['lng'] as double?;
      if (lat != null && lng != null) {
        coords.add((lat, lng));
      }
    }

    if (coords.isEmpty) return;

    renderer.fitBounds(
      coordinates: coords,
      maxZoom: 15.0,
      pitch: kIsWeb ? 0.0 : 15.0,
      bearing: 0.0,
    );
  }

  void _zoomIn() {
    final renderer = _rendererKey.currentState;
    if (renderer == null) return;
    final pos = _displayPosition ?? _rawPosition;
    renderer.flyTo(
      lng: pos?.longitude ?? -3.7038,
      lat: pos?.latitude ?? 40.4168,
      zoom: _currentZoom + 1,
      pitch: _currentPitch,
      bearing: _currentBearing,
      durationMs: 300,
    );
  }

  void _zoomOut() {
    final renderer = _rendererKey.currentState;
    if (renderer == null) return;
    final pos = _displayPosition ?? _rawPosition;
    renderer.flyTo(
      lng: pos?.longitude ?? -3.7038,
      lat: pos?.latitude ?? 40.4168,
      zoom: _currentZoom - 1,
      pitch: _currentPitch,
      bearing: _currentBearing,
      durationMs: 300,
    );
  }

  // ─── RENDERER CALLBACKS ───────────────────────────────────────────────────

  void _onMapReady(dynamic controller) {
    setState(() => _mapReady = true);
    final pos = _displayPosition ?? _rawPosition;
    if (pos != null) {
      _flyToUser(pos, animate: false);
    }
  }

  void _onCameraChanged({
    required double zoom,
    required double pitch,
    required double bearing,
  }) {
    if (mounted) {
      setState(() {
        _currentZoom = zoom;
        _currentPitch = pitch;
        _currentBearing = bearing;
      });
      _scheduleOverlayRebuild();
    }
  }

  void _onMapScroll() {
    if (_cameraMode == _CameraMode.followMe) {
      setState(() => _cameraMode = _CameraMode.free);
    }
  }

  // ─── OVERLAY POSITIONING ──────────────────────────────────────────────────

  void _scheduleOverlayRebuild() {
    _overlayRebuildTimer?.cancel();
    _overlayRebuildTimer = Timer(const Duration(milliseconds: 16), () {
      _rebuildOverlayPositions();
    });
  }

  Future<void> _rebuildOverlayPositions() async {
    final renderer = _rendererKey.currentState;
    if (renderer == null || !_mapReady || !mounted) return;

    final newPositions = <String, Offset>{};

    final ownPos = _displayPosition ?? _rawPosition;
    final ownId = SupabaseService.instance.currentUserId ?? 'own';
    if (ownPos != null && !_ghostMode) {
      final sc = await renderer.coordinateToScreen(
        ownPos.latitude,
        ownPos.longitude,
      );
      if (sc != null) newPositions[ownId] = sc;
    }

    for (final m in _memberMaps) {
      final lat = m['lat'] as double?;
      final lng = m['lng'] as double?;
      final id = m['id'] as String?;
      if (lat != null && lng != null && id != null) {
        final sc = await renderer.coordinateToScreen(lat, lng);
        if (sc != null) newPositions[id] = sc;
      }
    }

    if (mounted) {
      setState(() {
        _overlayPositions.clear();
        _overlayPositions.addAll(newPositions);
      });
    }
  }

  // ─── GROUPS & LOCATIONS ───────────────────────────────────────────────────

  Future<void> _loadGroups() async {
    if (!mounted) return;
    setState(() => _isLoadingGroups = true);
    try {
      final groups = await SupabaseService.instance.getMyGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _isLoadingGroups = false;

        if (groups.isEmpty) {
          _selectedGroupId = null;
          _selectedGroupName = '';
          _memberMaps = [];
        } else {
          final stillExists =
              _selectedGroupId != null &&
              groups.any((g) => g['id'] == _selectedGroupId);

          if (!stillExists) {
            _selectedGroupId = groups.first['id'] as String;
            _selectedGroupName = groups.first['name'] as String;
          } else {
            final current = groups.firstWhere(
              (g) => g['id'] == _selectedGroupId,
            );
            _selectedGroupName = current['name'] as String;
          }
        }
      });

      if (_selectedGroupId != null) {
        _loadLocations(_selectedGroupId!);
        _subscribeToLocations(_selectedGroupId!);
        final pos = _displayPosition ?? _rawPosition;
        if (pos != null) {
          _writeLocation(pos);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  Future<void> _loadLocations(String groupId) async {
    if (!mounted) return;
    setState(() => _isLoadingLocations = true);
    try {
      final locations = await SupabaseService.instance.getGroupLocations(
        groupId,
      );
      if (mounted) {
        setState(() {
          _memberMaps = _buildMemberMaps(locations);
          _isLoadingLocations = false;
        });
        _scheduleOverlayRebuild();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  void _subscribeToLocations(String groupId) {
    _locationChannel?.unsubscribe();
    _locationChannel = SupabaseService.instance.subscribeToGroupLocations(
      groupId,
      (payload) {
        if (mounted) _loadLocations(groupId);
      },
    );
  }

  List<Map<String, dynamic>> _buildMemberMaps(
    List<Map<String, dynamic>> locations,
  ) {
    final currentUserId = SupabaseService.instance.currentUserId;
    return locations.where((loc) => loc['user_id'] != currentUserId).map((loc) {
      final profile = loc['profiles'] as Map<String, dynamic>?;
      final colorHex = profile?['avatar_color'] as String? ?? '#06AED5';
      final color = _hexToColor(colorHex);
      final updatedAt = loc['updated_at'] as String?;
      final battery = loc['battery'] as int?;
      final avatarUrl = profile?['avatar_url'] as String?;
      final phone = profile?['phone'] as String?;

      return {
        'id': loc['user_id'] as String,
        'name': profile?['display_name'] as String? ?? 'Usuario',
        'role': 'member',
        'status': null,
        'sharingMode': 'exact',
        'lastSeen': updatedAt,
        'battery': battery,
        'speed': null,
        'lat': loc['lat'] as double,
        'lng': loc['lng'] as double,
        'color': color.value,
        'colorHex': colorHex,
        'avatarUrl': avatarUrl,
        'phone': phone,
      };
    }).toList();
  }

  Color _hexToColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  void _toggleGhostMode() {
    setState(() {
      _ghostMode = !_ghostMode;
      _ghostMinutesRemaining = _ghostMode ? 30 : null;
    });
    _scheduleOverlayRebuild();
  }

  void _dismissMemberSheet() {
    if (_selectedMemberId != null) {
      setState(() => _selectedMemberId = null);
      Navigator.of(context).maybePop();
    }
  }

  void _onMemberTapped(String memberId) {
    if (_selectedMemberId == memberId) {
      _dismissMemberSheet();
      return;
    }
    if (_selectedMemberId != null) {
      Navigator.of(context).maybePop();
    }
    setState(() {
      _selectedMemberId = memberId;
      _cameraMode = _CameraMode.free;
    });
    final member = _memberMaps.firstWhere((m) => m['id'] == memberId);

    final lat = member['lat'] as double?;
    final lng = member['lng'] as double?;
    final renderer = _rendererKey.currentState;
    if (lat != null && lng != null && renderer != null) {
      renderer.flyTo(
        lng: lng,
        lat: lat,
        zoom: _currentZoom,
        pitch: _currentPitch,
        bearing: _currentBearing,
        durationMs: 600,
      );
    }

    final memberData = PersonMapData(
      userId: member['id'] as String,
      displayName: member['name'] as String? ?? 'Usuario',
      avatarColorHex: member['colorHex'] as String? ?? '#06AED5',
      avatarUrl: member['avatarUrl'] as String?,
      lat: member['lat'] as double,
      lng: member['lng'] as double,
      updatedAt: member['lastSeen'] != null
          ? DateTime.tryParse(member['lastSeen'] as String)
          : null,
      battery: member['battery'] as int?,
      movementState: PersonMovementState.unknown,
      activityState: PersonActivityState.normal,
      phone: member['phone'] as String?,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PersonDetailSheet(
        data: memberData,
        isSelf: false,
        groupId: _selectedGroupId,
        groupName: _selectedGroupName.isNotEmpty ? _selectedGroupName : null,
        currentLat: memberData.lat,
        currentLng: memberData.lng,
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedMemberId = null);
    });
  }

  void _onOwnMarkerTapped() {
    if (_ownSheetOpen) return;
    setState(() => _ownSheetOpen = true);

    final pos = _displayPosition ?? _rawPosition;

    PersonMovementState movementState = PersonMovementState.unknown;
    if (pos?.speed != null) {
      movementState = pos!.speed > 0.5
          ? PersonMovementState.moving
          : PersonMovementState.stopped;
    }

    final ownData = PersonMapData(
      userId: SupabaseService.instance.currentUserId ?? '',
      displayName: _ownDisplayName,
      avatarColorHex: _ownAvatarColorHex,
      avatarUrl: _ownPhotoUrl,
      lat: pos?.latitude ?? 0,
      lng: pos?.longitude ?? 0,
      updatedAt: _lastLocationUpdate,
      battery: null,
      movementState: movementState,
      activityState: PersonActivityState.normal,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PersonDetailSheet(
        data: ownData,
        isSelf: true,
        groupId: _selectedGroupId,
        groupName: _selectedGroupName.isNotEmpty ? _selectedGroupName : null,
        currentLat: pos?.latitude,
        currentLng: pos?.longitude,
        lastLocationUpdate: _lastLocationUpdate,
        onProfileUpdated: () {
          _loadOwnProfile();
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _ownSheetOpen = false);
    });
  }

  void _onGroupChanged(String groupName) {
    final group = _groups.firstWhere(
      (g) => g['name'] == groupName,
      orElse: () => <String, dynamic>{},
    );
    if (group.isNotEmpty) {
      setState(() {
        _selectedGroupId = group['id'] as String;
        _selectedGroupName = groupName;
      });
      _loadLocations(_selectedGroupId!);
      _subscribeToLocations(_selectedGroupId!);
      final pos = _displayPosition ?? _rawPosition;
      if (pos != null) {
        _writeLocation(pos);
      }
    }
  }

  // ─── OVERLAY WIDGETS ──────────────────────────────────────────────────────

  List<Widget> _buildPersonOverlays() {
    final widgets = <Widget>[];
    final ownId = SupabaseService.instance.currentUserId ?? 'own';

    // ── Other members ────────────────────────────────────────────────────────
    for (final member in _memberMaps) {
      if (member['sharingMode'] == 'ghost') continue;
      final id = member['id'] as String;
      final screenPos = _overlayPositions[id];
      if (screenPos == null) continue;

      final isSelected = _selectedMemberId == id;
      final memberData = PersonMapData(
        userId: id,
        displayName: member['name'] as String? ?? 'Usuario',
        avatarColorHex: member['colorHex'] as String? ?? '#06AED5',
        avatarUrl: member['avatarUrl'] as String?,
        lat: member['lat'] as double,
        lng: member['lng'] as double,
        updatedAt: member['lastSeen'] != null
            ? DateTime.tryParse(member['lastSeen'] as String)
            : null,
        battery: member['battery'] as int?,
        movementState: PersonMovementState.unknown,
        activityState: PersonActivityState.normal,
        phone: member['phone'] as String?,
      );

      widgets.add(
        Positioned(
          left: screenPos.dx - PersonMapObjectWidget.kAnchorX,
          top: screenPos.dy - PersonMapObjectWidget.kAnchorY,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onMemberTapped(id),
            child: PersonMapObjectWidget(
              data: memberData,
              isSelf: false,
              isSelected: isSelected,
              currentZoom: _currentZoom,
            ),
          ),
        ),
      );
    }

    // ── Own user ─────────────────────────────────────────────────────────────
    if (!_ghostMode) {
      final ownScreenPos = _overlayPositions[ownId];
      if (ownScreenPos != null) {
        final pos = _displayPosition ?? _rawPosition;
        PersonMovementState movementState = PersonMovementState.unknown;
        if (pos?.speed != null) {
          movementState = pos!.speed > 0.5
              ? PersonMovementState.moving
              : PersonMovementState.stopped;
        }

        final ownData = PersonMapData(
          userId: ownId,
          displayName: _ownDisplayName,
          avatarColorHex: _ownAvatarColorHex,
          avatarUrl: _ownPhotoUrl,
          lat: pos?.latitude ?? 0,
          lng: pos?.longitude ?? 0,
          battery: null,
          movementState: movementState,
          activityState: PersonActivityState.normal,
        );

        widgets.add(
          Positioned(
            left: ownScreenPos.dx - PersonMapObjectWidget.kAnchorX,
            top: ownScreenPos.dy - PersonMapObjectWidget.kAnchorY,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onOwnMarkerTapped,
              child: PersonMapObjectWidget(
                data: ownData,
                isSelf: true,
                isSelected: _ownSheetOpen,
                currentZoom: _currentZoom,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groupNames = _groups.map((g) => g['name'] as String).toList();
    final memberCount = _memberMaps.length;

    // Initial camera center
    final initLng = _displayPosition?.longitude ?? -3.7038;
    final initLat = _displayPosition?.latitude ?? 40.4168;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── SentinelMapRenderer (platform-aware) ─────────────────────────
          SentinelMapRenderer.forPlatform(
            key: _rendererKey,
            initialLng: initLng,
            initialLat: initLat,
            initialZoom: 18.0,
            initialPitch: kIsWeb ? 0.0 : 50.0,
            initialBearing: 0.0,
            onMapReady: _onMapReady,
            onCameraChanged: _onCameraChanged,
            onMapScroll: _onMapScroll,
          ),

          // ── Person overlays (screen-space, above map) ────────────────────
          if (_mapReady) ..._buildPersonOverlays(),

          // ── Top overlay ──────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                MapGroupSelectorWidget(
                  selectedGroup: _selectedGroupName.isEmpty
                      ? (groupNames.isNotEmpty
                            ? groupNames.first
                            : 'Sin grupos')
                      : _selectedGroupName,
                  groups: groupNames.isEmpty ? ['Sin grupos'] : groupNames,
                  onGroupChanged: _onGroupChanged,
                  memberCount: memberCount,
                ),
                const SizedBox(height: 8),
                if (_isLoadingLocations)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Actualizando ubicaciones...',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                MemberAvatarStripWidget(
                  members: _memberMaps,
                  onMemberTapped: _onMemberTapped,
                ),
              ],
            ),
          ),

          // ── Location permission denied banner ────────────────────────────
          if (_locationPermissionDenied)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      color: AppTheme.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sentinel necesita tu ubicación para mostrarte en el mapa.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => geo.Geolocator.openAppSettings(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const ui.Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Activar',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Ghost chip + SOS ─────────────────────────────────────────────
          Positioned(
            bottom: 100,
            left: 16,
            child: GhostModeChipWidget(
              isActive: _ghostMode,
              minutesRemaining: _ghostMinutesRemaining,
              onToggle: _toggleGhostMode,
            ),
          ),

          Positioned(
            bottom: 88,
            right: 16,
            child: SosFabWidget(onSosPressed: () => _showSosDialog(context)),
          ),

          // ── Camera controls ───────────────────────────────────────────────
          Positioned(
            bottom: 160,
            right: 16,
            child: Column(
              children: [
                _MapControlButton(icon: Icons.add_rounded, onTap: _zoomIn),
                const SizedBox(height: 4),
                _MapControlButton(icon: Icons.remove_rounded, onTap: _zoomOut),
                const SizedBox(height: 4),
                _MapControlButton(
                  icon: Icons.my_location_rounded,
                  onTap: _moveToMyLocation,
                  color: _cameraMode == _CameraMode.followMe
                      ? AppTheme.primary
                      : null,
                ),
                if (_memberMaps.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _MapControlButton(
                    icon: Icons.group_rounded,
                    onTap: _fitAllMembers,
                  ),
                ],
              ],
            ),
          ),

          // ── Ghost mode banner ────────────────────────────────────────────
          if (_ghostMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(179),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_off_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Modo fantasma activo — nadie te ve en el mapa',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Empty state card when no groups (map stays usable) ──────────
          if (!_isLoadingGroups && _groups.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(38),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.group_add_rounded,
                            size: 28,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sin grupos activos',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Crea o únete a un grupo para ver a tu familia en el mapa.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.go(AppRoutes.groupsScreen),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.group_add_rounded, size: 20),
                          label: Text(
                            'Crear o unirme a un grupo',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.sosContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.sos_rounded, color: AppTheme.sos, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Alerta de emergencia'),
          ],
        ),
        content: const Text(
          'Se notificará a todos los miembros de tu grupo con tu ubicación exacta y se activará el escalado automático.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_selectedGroupId != null) {
                final pos = _displayPosition ?? _rawPosition;
                await SupabaseService.instance.createAlert(
                  groupId: _selectedGroupId!,
                  kind: 'emergency',
                  lat: pos?.latitude,
                  lng: pos?.longitude,
                );
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('🚨 Alerta de emergencia enviada'),
                    backgroundColor: AppTheme.sos,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.sos),
            child: const Text('Enviar SOS'),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color != null ? color!.withAlpha(30) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: color != null ? Border.all(color: color!, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: color ?? AppTheme.primary),
      ),
    );
  }
}
