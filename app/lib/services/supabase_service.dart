import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be defined using --dart-define.',
      );
    }
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;

  // ─── AUTH ────────────────────────────────────────────────────────────────

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
    if (response.user != null && displayName != null) {
      await _upsertProfile(response.user!.id, displayName: displayName);
    }
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ─── PROFILE ─────────────────────────────────────────────────────────────

  Future<void> _upsertProfile(String userId, {String? displayName}) async {
    try {
      await client.from('profiles').upsert({
        'id': userId,
        if (displayName != null) 'display_name': displayName,
      });
    } catch (e) {
      debugPrint('Profile upsert error: $e');
    }
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select(
            'id, display_name, phone, avatar_color, avatar_symbol, avatar_url, created_at',
          )
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Get profile error: $e');
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? phone,
    String? avatarColor,
    String? avatarSymbol,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (phone != null) updates['phone'] = phone;
    if (avatarColor != null) updates['avatar_color'] = avatarColor;
    if (avatarSymbol != null) updates['avatar_symbol'] = avatarSymbol;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isEmpty) return;
    await client.from('profiles').update(updates).eq('id', userId);
  }

  // ─── ROLE HELPERS ─────────────────────────────────────────────────────────

  /// Returns the current user's role in a group, or null if not a member.
  Future<String?> getMyRoleInGroup(String groupId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;
      final result = await client
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();
      return result?['role'] as String?;
    } catch (e) {
      debugPrint('Get my role error: $e');
      return null;
    }
  }

  /// Returns true if the current user is owner or admin of the given group.
  bool isAdminRole(String? role) => role == 'owner' || role == 'admin';

  // ─── GROUPS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyGroups() async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      final memberRows = await client
          .from('group_members')
          .select('group_id, role, status')
          .eq('user_id', userId)
          .eq('status', 'active');

      if (memberRows.isEmpty) return [];

      final groupIds = (memberRows as List)
          .map((r) => r['group_id'] as String)
          .toList();

      final groups = await client
          .from('groups')
          .select('id, name, owner_id, created_at')
          .inFilter('id', groupIds);

      // Enrich with member info
      final enriched = <Map<String, dynamic>>[];
      for (final g in (groups as List)) {
        final members = await client
            .from('group_members')
            .select(
              'user_id, role, status, profiles(id, display_name, avatar_color, avatar_symbol)',
            )
            .eq('group_id', g['id'])
            .eq('status', 'active');

        final myMembership = (memberRows as List).firstWhere(
          (r) => r['group_id'] == g['id'],
          orElse: () => {},
        );

        enriched.add({
          ...g,
          'members': members,
          'myRole': myMembership['role'] ?? 'member',
          'memberCount': (members as List).length,
          'activeCount': (members as List)
              .where((m) => m['role'] != 'guest')
              .length,
        });
      }
      return enriched;
    } catch (e) {
      debugPrint('Get groups error: $e');
      return [];
    }
  }

  /// Checks whether the current user has the can_create_groups capability.
  Future<bool> canCreateGroups() async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;
      final result = await client
          .from('profiles')
          .select('can_create_groups')
          .eq('id', userId)
          .maybeSingle();
      return (result?['can_create_groups'] as bool?) ?? false;
    } catch (e) {
      debugPrint('canCreateGroups error: $e');
      return false;
    }
  }

  /// Grants can_create_groups = TRUE to the current user via the
  /// grant_can_create_groups RPC (SECURITY DEFINER).
  /// Called during administrator onboarding.
  Future<void> grantCanCreateGroups() async {
    try {
      final userId = currentUserId;
      if (userId == null) return;
      await client.rpc(
        'grant_can_create_groups',
        params: {'p_user_id': userId},
      );
    } catch (e) {
      debugPrint('grantCanCreateGroups error: $e');
    }
  }

  /// Atomically creates a group and inserts the caller as owner via RPC.
  /// Returns the created group map on success, or null on failure.
  /// The RPC checks profiles.can_create_groups before proceeding.
  Future<Map<String, dynamic>?> createGroupAsOwner({
    required String name,
    String? description,
  }) async {
    try {
      final result = await client.rpc(
        'create_group_as_owner',
        params: {
          'p_name': name,
          if (description != null && description.isNotEmpty)
            'p_description': description,
        },
      );
      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        if (map.containsKey('error')) {
          debugPrint('createGroupAsOwner RPC error: ${map['error']}');
          return null;
        }
        return map;
      }
      return null;
    } catch (e) {
      debugPrint('createGroupAsOwner error: $e');
      return null;
    }
  }

  /// Creates a new group. Only the first owner insert is allowed by RLS.
  /// @deprecated Use createGroupAsOwner() instead for atomic creation.
  Future<Map<String, dynamic>?> createGroup({
    required String name,
    String? description,
    String? emoji,
    String? color,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final group = await client
          .from('groups')
          .insert({'name': name, 'owner_id': userId})
          .select()
          .single();

      // Add creator as owner — RLS allows role='owner' for self-insert
      await client.from('group_members').insert({
        'group_id': group['id'],
        'user_id': userId,
        'role': 'owner',
        'status': 'active',
      });

      return group;
    } catch (e) {
      debugPrint('Create group error: $e');
      return null;
    }
  }

  /// Creates an invitation. RLS enforces that caller must be owner/admin.
  Future<Map<String, dynamic>?> createInvitation({
    required String groupId,
    String? contact,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      // Token is generated server-side (uuid default), we omit it from insert
      // so Postgres gen_random_uuid() is used — avoids the hex-string type mismatch.
      final invitation = await client
          .from('invitations')
          .insert({
            'group_id': groupId,
            'invited_by': userId,
            if (contact != null) 'contact': contact,
            'status': 'prepared',
          })
          .select()
          .single();

      return invitation;
    } catch (e) {
      debugPrint('Create invitation error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getInvitationByToken(String token) async {
    try {
      final result = await client
          .from('invitations')
          .select('group_id, invited_by, status, token, created_at')
          .eq('token', token)
          .maybeSingle();
      return result;
    } catch (e) {
      debugPrint('Get invitation by token error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getGroupById(String groupId) async {
    try {
      final result = await client
          .from('groups')
          .select('id, name, owner_id, created_at')
          .eq('id', groupId)
          .maybeSingle();
      return result;
    } catch (e) {
      debugPrint('Get group by id error: $e');
      return null;
    }
  }

  Future<bool> isGroupMember(String groupId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;
      final result = await client
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();
      return result != null;
    } catch (e) {
      debugPrint('Is group member error: $e');
      return false;
    }
  }

  /// Atomic invitation acceptance via RPC.
  /// Returns a map with 'group_id' on success, or 'error' on failure.
  Future<Map<String, dynamic>> acceptInvitationAtomic(String token) async {
    try {
      final result = await client.rpc(
        'accept_invitation',
        params: {'p_token': token},
      );
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return {'error': 'unexpected_response'};
    } catch (e) {
      debugPrint('Accept invitation RPC error: $e');
      return {'error': e.toString()};
    }
  }

  // Kept for backward compatibility — prefer acceptInvitationAtomic
  Future<void> joinGroup({required String groupId}) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;
      await client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
        'status': 'active',
      });
    } catch (e) {
      debugPrint('Join group error: $e');
      rethrow;
    }
  }

  Future<void> updateInvitationStatus({
    required dynamic invitationId,
    required String status,
  }) async {
    try {
      // invitationId is the token (UUID) — the PK of the invitations table
      await client
          .from('invitations')
          .update({'status': status})
          .eq('token', invitationId);
    } catch (e) {
      debugPrint('Update invitation status error: $e');
    }
  }

  // ─── LOCATIONS ───────────────────────────────────────────────────────────

  Future<void> upsertLocation({
    required String groupId,
    required double lat,
    required double lng,
    double? accuracy,
    int? battery,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await client.from('locations').upsert({
        'user_id': userId,
        'group_id': groupId,
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
        if (battery != null) 'battery': battery,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Upsert location error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getGroupLocations(String groupId) async {
    try {
      final response = await client
          .from('locations')
          .select(
            'user_id, lat, lng, accuracy, battery, updated_at, profiles(id, display_name, avatar_color, avatar_symbol, avatar_url, phone)',
          )
          .eq('group_id', groupId);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Get locations error: $e');
      return [];
    }
  }

  RealtimeChannel subscribeToGroupLocations(
    String groupId,
    void Function(Map<String, dynamic> payload) onUpdate,
  ) {
    return client
        .channel('locations:$groupId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: groupId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  // ─── ALERTS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGroupAlerts(String groupId) async {
    try {
      final response = await client
          .from('alert_events')
          .select(
            'id, user_id, group_id, kind, status, lat, lng, created_at, profiles(id, display_name, avatar_color)',
          )
          .eq('group_id', groupId)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Get alerts error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyAlerts() async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      final memberRows = await client
          .from('group_members')
          .select('group_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      if ((memberRows as List).isEmpty) return [];

      final groupIds = memberRows.map((r) => r['group_id'] as String).toList();

      final response = await client
          .from('alert_events')
          .select(
            'id, user_id, group_id, kind, status, lat, lng, created_at, profiles(id, display_name, avatar_color)',
          )
          .inFilter('group_id', groupIds)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Get my alerts error: $e');
      return [];
    }
  }

  Future<void> createAlert({
    required String groupId,
    required String kind,
    double? lat,
    double? lng,
    String? targetUserId,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await client.from('alert_events').insert({
        'user_id': userId,
        'group_id': groupId,
        'kind': kind,
        'status': 'open',
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (targetUserId != null) 'target_user_id': targetUserId,
      });
    } catch (e) {
      debugPrint('Create alert error: $e');
    }
  }

  Future<void> updateAlertStatus({
    required int alertId,
    required String status,
  }) async {
    try {
      await client
          .from('alert_events')
          .update({'status': status})
          .eq('id', alertId);
    } catch (e) {
      debugPrint('Update alert error: $e');
    }
  }

  RealtimeChannel subscribeToAlerts(
    List<String> groupIds,
    void Function(Map<String, dynamic> payload) onEvent,
  ) {
    return client
        .channel('alerts:${groupIds.join(',')}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alert_events',
          callback: (payload) => onEvent(payload.newRecord),
        )
        .subscribe();
  }
}
