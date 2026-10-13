# PROMPT PARA ROCKET — P1: integrar en Flutter, compilar y ejecutar el test de 6 miembros

**De:** Juan (fundador) vía K200 · **Fecha:** 2026-09-16 (v2 — corregido a Flutter)
**Proyecto:** Sentinel Family · **App:** Flutter/Dart (repo `Momentumsystems1/sentinelfamily`)
**Entorno:** SOLO dev (`nvannetdrfybowwjqqhf`). Prod prohibido.

---

## Contexto

La Spec P1 (invitaciones + onboarding de círculo + autorización de círculos nuevos) está
aprobada por Juan y la **base de datos ya está migrada y verificada por K200**.
Tu trabajo: integrar 5 cambios en la app Flutter (hay código Dart de referencia listo),
compilar, y ejecutar con Juan el test de aceptación de 8 pasos con evidencia.

La spec (`docs/Spec_P1_invitaciones_y_circulos_para_Rocket.md`) se escribió contra un
código Expo que no es esta app: **su modelo de datos, flujos y test siguen vigentes;
las rutas de archivos de su §3 quedan sustituidas por `docs/p1_reference_flutter/INTEGRACION_FLUTTER.md`**.

## Lo que YA está hecho (no lo repitas)

1. **Migración dev aplicada** (SQL y evidencia en `docs/migrations/2026-09-16_p1_invitaciones.sql`):
   - `invitations` extendida (invitee_name, membership, role, expires_at, accepted_by/at, status ampliado).
   - `group_members` + `membership` + `expires_at`, status con 'expired'.
   - `circle_requests` nueva + RLS + índice anti-spam.
   - RPCs: `accept_invitation` (upgrade: hereda rol/membership/expiración), `decide_circle_request`,
     `expire_temporary_memberships`, `get_invitation_preview` (anon+authenticated).
   - pg_cron: expiración automática cada hora.
2. **Auth dev:** `mailer_autoconfirm=true` (signup con sesión inmediata — necesario para el test).
3. **Paso 0 hecho:** "Familia Centro Madrid" tiene UN solo miembro: Juan (`juan@sentinel.dev`, owner).
4. **Código Dart de referencia:** `docs/p1_reference_flutter/` (mismo repo).

## Tu tarea (en orden)

### 1. Integra los 5 cambios (guía: `docs/p1_reference_flutter/INTEGRACION_FLUTTER.md`)

- **a)** `lib/services/supabase_service.dart`: añadir los métodos de `supabase_service_p1.dart`
  (createInvitation con membership/expiresAt/inviteeName, getInvitationPreview, circle requests).
- **b)** `invite_sheet_widget.dart`: SUSTITUIR por `invite_sheet_widget_p1.dart`
  (nombre del invitado, fijo/temporal, selector D4: 24 h / 7 días / 30 días / fecha personalizada;
  sin duración no se crea el enlace). **ELIMINA el fallback `/join/demo`** — es simulación y usa
  una palabra prohibida en texto visible.
- **c)** `join_invitation_screen.dart`: seguir `join_screen_p1.md`. CRÍTICO: hoy el flujo está
  roto para invitados reales — RLS impide leer la invitación sin sesión de admin y todo invitado
  ve "no existe o ha expirado". Cambiar a `getInvitationPreview` y mostrar la bienvenida
  personalizada (círculo, quién invita, temporalidad, saludo por nombre).
- **d)** Perfil: montar `CreateCircleSection` (popup con copy LITERAL de Juan:
  "Para crear tu círculo necesitas autorización del administrador" + nombre + Enviar).
- **e)** `groups_screen.dart`: montar `CircleRequestsInbox` (solo owner/admin) con
  Aceptar/Denegar → RPC `decide_circle_request`. Tras aprobar, refrescar grupos con
  `GroupChangeNotifier` (el solicitante se mueve a su nuevo círculo, D2).

### 2. Compila y verifica en dev

- `flutter analyze` limpio en los archivos tocados; build web + Android dev contra `nvannetdrfybowwjqqhf`.
- Prueba de humo obligatoria: crea una invitación como Juan y abre el link en **incógnito**
  (sin sesión) → debe verse la bienvenida personalizada (antes de este cambio salía error).
- 0 errores de consola en los flujos tocados.

### 3. Ejecuta con Juan el test de aceptación (spec §4)

**REGLA DE ORO: los 5 testers hacen su propio signup a través del link de invitación.
PROHIBIDO crear sus cuentas por SQL, Admin API o semilla.** La única cuenta preexistente
es `juan@sentinel.dev` (owner).

| # | Paso | Evidencia exigida |
| --- | --- | --- |
| 1 | Juan invita a F1 y F2 (fijos) por enlace | fila `invitations` + captura del link |
| 2 | Juan promueve a F1 a admin; F1 invita a T1 (temporal 24 h, duración elegida por F1) | captura hoja de F1 con selector de duración |
| 3 | Juan invita a T2 (7 días) y T3 (30 días) | 2 filas `membership='temporary'` con `expires_at` distintos |
| 4 | Cada invitado abre su link, hace signup y onboarding personalizado | captura bienvenida + perfil + entrada al mapa |
| 5 | T1 intenta crear círculo nuevo → popup → Enviar | captura popup + fila `circle_requests` |
| 6 | Juan deniega a T1 y acepta a F2 | captura bandeja + estados finales |
| 7 | F2 se mueve a su nuevo círculo como owner; T1 recibe "Denegada" | SQL de verificación + capturas |
| 8 | Forzar expiración de T3 (fecha al pasado en dev) → 'expired' y pierde acceso | SQL + captura de su pantalla |

**Criterio de aprobado:** pasos 1–8 con evidencia, 0 cuentas de tester creadas por
SQL/Admin API, 0 errores de consola.

## Prohibido

- Tocar prod (`wmidlrhbkpzaepkybxjk`, 23 usuarios reales).
- Debilitar RLS o tocar policies existentes.
- Service key en la app. Palabra "demo" en texto visible.
- Simular éxito en tokens inválidos; etiquetas de dispatch que el SO no confirmó.

## Entrega

Informe con: build (web + Android), capturas por paso, SQL de verificación,
y lista de desviaciones del código de referencia (si las hay) con justificación.
