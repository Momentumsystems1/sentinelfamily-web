# P1 §3.2 — Cambios en `join_invitation_screen.dart`

## El problema (CRÍTICO — el flujo actual está roto para invitados reales)

`_loadInvitation()` llama a `getInvitationByToken()` (SELECT directo sobre
`invitations`) y luego `getGroupById()`. La policy RLS `invitations_select` es
`invited_by = auth.uid() OR is_group_admin(group_id)`: **un invitado anónimo o
recién registrado NO puede leer la invitación ni el grupo**. Resultado: todo
invitado real ve "La invitación no existe o ha expirado". El flujo solo
"funcionaba" si lo probaba el propio invitador con su sesión.

## La solución (ya desplegada en dev)

RPC `get_invitation_preview(p_token)` — security definer, grant a anon +
authenticated. El token uuid ES el secreto. Devuelve:

```json
{ "group_name": "Familia Centro Madrid", "inviter_name": "Juan",
  "invitee_name": "María", "membership": "temporary",
  "expires_at": "2026-09-17T15:28:34+00:00" }
```
o `{ "error": "invitation_not_found" | "invitation_not_valid" | "invitation_expired" }`

## Cambios concretos

1. **Sustituir `_loadInvitation()`** para usar
   `SupabaseService.instance.getInvitationPreview(widget.token)`
   (método nuevo en `supabase_service_p1.dart`). Eliminar las llamadas a
   `getInvitationByToken` + `getGroupById` de esta pantalla.

2. **Bienvenida personalizada** (lo que Juan quiere ver en el paso 4 del test).
   Con el preview mostrar:
   - Nombre del círculo: `preview['group_name']`
   - Quién invita: `"{inviter_name} te ha invitado"`
   - Tipo: si `membership == 'temporary'` →
     `"Invitación temporal · acceso hasta el {expires_at formateada}"`;
     si no → `"Invitación sin expiración"`
   - Si `invitee_name` viene informado, saludar: `"Hola, {invitee_name}"`
   - Qué verán los demás: "Los demás verán tu nombre y tu posición cuando la compartas."

3. **Token en `_acceptInvitation()`**: el preview no devuelve el token (no hace
   falta) — usar directamente `widget.token` en `acceptInvitationAtomic(widget.token)`.

4. **Pantalla de invitación no válida**: la actual ya es honesta
   ("Esta invitación ya no es válida · pide una nueva a quien te la envió").
   Mantenerla. Nunca simular éxito.

5. **Signup redirect**: el flujo actual (redirect a
   `signUpLoginScreen?redirect=/join/{token}` y vuelta) es válido para el test.
   En dev `mailer_autoconfirm=true` → la sesión es inmediata tras el signup.
   Si la pantalla de signup pide nombre visible, guardarlo en
   `profiles.display_name` ANTES de volver al join (evidencia del paso 4:
   bienvenida + perfil + mapa).
