> ⚠️ OBSOLETO (2026-09-16): este paquete es TypeScript/Expo. La app real es Flutter. Usar `docs/p1_reference_flutter/` y su INTEGRACION_FLUTTER.md.

# P1 — Notas de integración para Rocket (v2.2.0)

**Base de datos: YA HECHO por K200 (2026-09-16).** Migración aplicada a dev
(`nvannetdrfybowwjqqhf`) con evidencia. NO ejecutéis otra migración para P1.
SQL completo en `docs/migrations/2026-09-16_p1_invitaciones.sql`.

Lo que ya existe en dev:
- `invitations` extendida: `invitee_name`, `membership` ('fixed'/'temporary'),
  `role` ('member'/'guest'), `expires_at`, `accepted_by`, `accepted_at`,
  status ampliado ('pending','prepared','dispatched','accepted','declined','expired','revoked'),
  default 'pending'. Si membership='temporary', `expires_at` es obligatorio (CHECK).
- `group_members`: + `membership` (default 'fixed'), + `expires_at`,
  status ampliado con 'expired'.
- `circle_requests` (nueva) + RLS (insert miembro activo / select solicitante o admin /
  update admin) + índice único anti-spam (una pendiente por usuario).
- RPCs `security definer`: `accept_invitation(uuid)`, `decide_circle_request(uuid,boolean,text)`,
  `expire_temporary_memberships()`, `get_invitation_preview(uuid)` (anon+authenticated).
- pg_cron: job `expire-temporary-memberships` cada hora (minuto 15).
- Auth dev: `mailer_autoconfirm=true` (signup con sesión inmediata; SOLO dev).
- Paso 0 hecho: "Familia Centro Madrid" = solo Juan (owner, juan@sentinel.dev). Count 5→1.

## Lo que queda en la app (4 cambios)

### 1. `src/invites.ts` → sustituir por `invites.supabase.ts`
La capa `src/api.ts` está muerta: todo va a Supabase directo.
Ajustar: import del cliente `supabase` y `EXPO_PUBLIC_WEB_BASE_URL` (dominio web dev
para los links `https://<web-dev>/unirse/{token}`).

### 2. `src/components/sheets.tsx` — selector de duración D4
La hoja `AddMemberSheet` existe pero está huérfana y sus chips (4h/24h/72h/168h)
NO son los de D4. Cambiar el bloque de duración a:

- Chips: **24 h / 7 días / 30 días / Fecha personalizada**
- `NewInvite` pasa a llevar `expiresAt?: string | null` (ISO) en vez de `duration_hours`.
- Fecha personalizada: picker nativo (`@react-native-community/datetimepicker` ya está
  en el proyecto o añadirlo) → `expiresAt = fecha elegida a las 23:59`.
- **Sin duración elegida no se puede enviar** (botón deshabilitado).
- Cablear la hoja desde `grupo.tsx` con `InviteSection` (ver `grupo-admin-section.tsx`).

### 3. Ruta nueva `app/unirse/[token].tsx`
Usar `unirse-[token].tsx` de este paquete. Flujo: preview (RPC `get_invitation_preview`)
→ bienvenida personalizada → signup → consentimientos (`REQUIRED_DOCS`) → perfil
(nombre + color) → RPC `accept_invitation` → `router.replace('/(tabs)/mapa')`.
Token inválido/usado/expirado → pantalla honesta. Nunca simular éxito.
Referencia visual: `src/_retired/invite/[token].tsx` y `MobileJoin.jsx` (repo200).

### 4. Perfil + `grupo.tsx` — autorización de círculos nuevos (spec 3.3)
- Perfil: montar `CreateCircleSection` (popup con copy LITERAL de Juan:
  "Para crear tu círculo necesitas autorización del administrador" + campo nombre + Enviar).
- `grupo.tsx`: montar `CircleRequestsInbox` (visible solo owner/admin) con
  Aceptar/Denegar → RPC `decide_circle_request`. Badge con nº de pendientes en la tab Grupo.
- Tras aprobar, el solicitante SE MUEVE al nuevo círculo (D2): invalidar la query
  del grupo activo para que su app recargue el nuevo grupo.

## Tipos TS de las respuestas RPC

```ts
// accept_invitation → { group_id, group_name, role, membership, expires_at } | { error }
// errores: not_authenticated | invitation_not_found | already_accepted |
//          invitation_declined | invitation_expired | invitation_revoked
// decide_circle_request → { status:'approved', new_group_id, group_name } | { status:'denied' } | { error }
// get_invitation_preview → { group_name, inviter_name, invitee_name, membership, expires_at } | { error }
```

## Prohibido (reglas del proyecto)

- No debilitar RLS. Ninguna policy existente se toca.
- Ninguna clave en el cliente. Service key NUNCA en la app.
- Los 5 testers del test hacen su propio signup vía link. PROHIBIDO crear sus
  cuentas por SQL/Admin API/semilla.
- Palabra "demo" prohibida en texto visible. Etiquetas honestas en dispatch.
