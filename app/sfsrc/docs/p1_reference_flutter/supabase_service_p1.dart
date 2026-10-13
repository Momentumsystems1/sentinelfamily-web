// P1 — Métodos para lib/services/supabase_service.dart (Flutter)
// Añadir/sustituir en la clase SupabaseService. La BD dev YA está migrada (K200, 2026-09-16).
// No ejecutar ninguna migración: tablas, RLS y RPCs ya existen.

// ─── 3.1 INVITAR ────────────────────────────────────────────

/// SUSTITUYE al createInvitation actual (que solo mandaba contact + 'prepared').
/// Spec 2.1 + D4: membership ('fixed'|'temporary'), expiresAt ISO obligatorio si temporal.
Future<Map<String, dynamic>?> createInvitation({
  required String groupId,
  required String inviteeName,
  required String membership, // 'fixed' | 'temporary'
  String role = 'member', // 'member' | 'guest'
  String? expiresAt, // ISO 8601; OBLIGATORIO si membership == 'temporary'
  String? contact,
}) async {
  try {
    final userId = currentUserId;
    if (userId == null) return null;
    if (membership == 'temporary' && expiresAt == null) {
      throw ArgumentError('expiresAt es obligatorio para invitados temporales (D4)');
    }
    final invitation = await client
        .from('invitations')
        .insert({
          'group_id': groupId,
          'invited_by': userId,
          'invitee_name': inviteeName,
          'membership': membership,
          'role': role,
          'expires_at': membership == 'temporary' ? expiresAt : null,
          if (contact != null) 'contact': contact,
          'status': 'pending',
        })
        .select()
        .single();
    return invitation;
  } catch (e) {
    debugPrint('Create invitation error: $e');
    return null;
  }
}

/// Marca la invitación como 'dispatched' tras abrir WhatsApp/SMS (etiquetas honestas).
Future<void> markInvitationDispatched(String token) async {
  try {
    await client
        .from('invitations')
        .update({'status': 'dispatched'})
        .eq('token', token);
  } catch (e) {
    debugPrint('Mark dispatched error: $e');
  }
}

// ─── 3.2 UNIRSE (preview seguro para anónimos) ─────────────

/// SUSTITUYE a getInvitationByToken + getGroupById en la pantalla de unirse.
/// Motivo: RLS (invitations_select = inviter o admin) hace que un invitado
/// anónimo NO pueda leer la invitación — el flujo actual está roto para él.
/// Este RPC es security definer y el token uuid ES el secreto.
/// Devuelve: {group_name, inviter_name, invitee_name, membership, expires_at}
/// o {error: 'invitation_not_found' | 'invitation_not_valid' | 'invitation_expired'}
Future<Map<String, dynamic>?> getInvitationPreview(String token) async {
  try {
    final result = await client.rpc(
      'get_invitation_preview',
      params: {'p_token': token},
    );
    if (result is Map<String, dynamic>) return result;
    return null;
  } catch (e) {
    debugPrint('Get invitation preview error: $e');
    return null;
  }
}

// ─── 3.3 CÍRCULOS NUEVOS (autorización del administrador) ──

/// El miembro solicita crear su círculo (insert directo; RLS: miembro activo).
/// Devuelve null si ya tiene una pendiente (índice único anti-spam, código 23505).
Future<String?> createCircleRequest({
  required String groupId,
  required String desiredName,
}) async {
  try {
    final userId = currentUserId;
    if (userId == null) return 'not_authenticated';
    await client.from('circle_requests').insert({
      'requester_user_id': userId,
      'group_id': groupId,
      'desired_name': desiredName,
    });
    return null; // éxito
  } on PostgrestException catch (e) {
    if (e.code == '23505') return 'already_pending';
    debugPrint('Create circle request error: ${e.message}');
    return 'error';
  } catch (e) {
    debugPrint('Create circle request error: $e');
    return 'error';
  }
}

/// Bandeja del admin: solicitudes pendientes del grupo (RLS: owner/admin).
Future<List<Map<String, dynamic>>> getPendingCircleRequests(String groupId) async {
  try {
    final result = await client
        .from('circle_requests')
        .select('id, desired_name, created_at, '
            'requester:profiles!circle_requests_requester_user_id_fkey(display_name)')
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .order('created_at');
    return List<Map<String, dynamic>>.from(result);
  } catch (e) {
    debugPrint('Get pending circle requests error: $e');
    return [];
  }
}

/// Estado de la última solicitud del usuario actual (para su pantalla de Perfil).
Future<Map<String, dynamic>?> getMyLatestCircleRequest() async {
  try {
    final userId = currentUserId;
    if (userId == null) return null;
    final result = await client
        .from('circle_requests')
        .select('status, desired_name')
        .eq('requester_user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return result;
  } catch (e) {
    debugPrint('Get my circle request error: $e');
    return null;
  }
}

/// Admin decide. RPC security definer (valida owner/admin del grupo origen).
/// approve=true → crea el grupo y MUEVE al solicitante como owner (D2).
/// Devuelve {status: 'approved'|'denied', ...} o {error: ...}.
Future<Map<String, dynamic>> decideCircleRequest({
  required String requestId,
  required bool approve,
}) async {
  try {
    final result = await client.rpc(
      'decide_circle_request',
      params: {'p_request_id': requestId, 'p_approve': approve},
    );
    if (result is Map<String, dynamic>) return result;
    return {'error': 'unexpected_response'};
  } catch (e) {
    debugPrint('Decide circle request error: $e');
    return {'error': e.toString()};
  }
}
