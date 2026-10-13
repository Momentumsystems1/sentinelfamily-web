# P1 — Integración Flutter para Rocket (repo `sentinelfamily`)

**Corrección de rumbo (2026-09-16):** la Spec P1 se escribió auditando un código
Expo que NO es esta app. El modelo de datos, los flujos y el test de la spec
siguen 100% vigentes; lo que cambia es el mapeo de archivos (§3). Este documento
sustituye a las rutas Expo de la spec. La BD dev YA está migrada por K200 —
**no ejecutéis ninguna migración**.

## Lo que la app Flutter YA tiene (no rehacer)

- Hoja de invitación cableada (`invite_sheet_widget.dart`) con WhatsApp/SMS/copiar.
- Ruta `/join/:token` (go_router) que salta el redirect de auth.
- `join_invitation_screen.dart` con aceptación vía RPC y errores honestos.
- `SupabaseService`: `createInvitation`, `acceptInvitationAtomic`, `canCreateGroups`,
  `createGroupAsOwner`, `getMyGroups`.
- Capability `can_create_groups` en profiles.

## Los 5 cambios P1 (en orden)

### 1. `supabase_service.dart` — añadir métodos
Copiar de `supabase_service_p1.dart`: `createInvitation` (nueva firma con
inviteeName/membership/expiresAt — sustituye a la actual), `markInvitationDispatched`,
`getInvitationPreview`, `createCircleRequest`, `getPendingCircleRequests`,
`getMyLatestCircleRequest`, `decideCircleRequest`.

### 2. `invite_sheet_widget.dart` — SUSTITUIR por `invite_sheet_widget_p1.dart`
Añade: nombre del invitado, fijo/temporal, selector D4 (24 h / 7 días / 30 días /
fecha personalizada), creación del enlace al pulsar botón (no en initState).
**ELIMINA el fallback `/join/demo`** — prohibido simular y prohibida esa palabra
en texto visible. Sin duración elegida no se crea el enlace.

### 3. `join_invitation_screen.dart` — seguir `join_screen_p1.md`
CRÍTICO: el flujo actual está roto para invitados reales (RLS impide leer la
invitación sin sesión de admin). Cambiar a `getInvitationPreview` y mostrar la
bienvenida personalizada (círculo, quién invita, temporalidad, saludo por nombre).

### 4. Perfil — montar `CreateCircleSection` (de `circle_request_widgets.dart`)
Popup con copy LITERAL de Juan: "Para crear tu círculo necesitas autorización
del administrador" + campo nombre + botón Enviar. Estado visible para el
solicitante (pendiente / aceptada / denegada).

### 5. `groups_screen.dart` — montar `CircleRequestsInbox`
Sección visible solo si el usuario es owner/admin del grupo activo, con
Aceptar/Denegar → `decideCircleRequest`. Tras aprobar, el solicitante SE MUEVE
al nuevo círculo (D2): usar `GroupChangeNotifier` para refrescar grupos en
todos los clientes. Badge con nº de pendientes opcional pero recomendado.

## Verificación antes de compilar

- `flutter analyze` limpio en los archivos tocados.
- Flujo invitado real: crear invitación como Juan → abrir el link en navegador
  de incógnito (sin sesión) → debe verse la bienvenida personalizada
  (antes de este cambio salía "no existe o ha expirado").
- Crear invitación temporal sin elegir duración → botón deshabilitado.

## Prohibido (reglas del proyecto)

- No debilitar RLS. Ninguna policy existente se toca.
- Ninguna clave en el cliente. Service key NUNCA en la app.
- Los 5 testers hacen su propio signup vía link. PROHIBIDO crear cuentas por
  SQL/Admin API/semilla.
- Palabra "demo" prohibida en texto visible. Etiquetas honestas en dispatch
  (nunca "enviado" sin confirmación del SO).
