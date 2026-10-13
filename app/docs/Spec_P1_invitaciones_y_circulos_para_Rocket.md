# SPEC P1 — Invitaciones, onboarding de círculo y autorización de círculos nuevos

**De:** K200 · **Para:** Rocket (implementación) · **Fecha:** 2026-09-16
**Proyecto:** Sentinel Family (Proyecto Frankenstein) · **App:** v2.2.0 (Expo → Supabase directo)
**Estado:** ✅ APROBADA POR JUAN 2026-09-16 (D1 OK) — Lista para implementar. Bloquea el test de 6 miembros. Nada de esto toca prod.

**Decisiones del fundador (cerradas 2026-09-16):**
- **D2 — Al aprobar un círculo nuevo:** el solicitante **se mueve** al nuevo círculo como owner (la app lee un solo grupo por usuario; multi-grupo queda para P2).
- **D3 — Cuentas del test:** **6 en total** = Juan (owner) + 5 invitados (2 fijos + 3 temporales).
- **D4 — Duración de invitados temporales:** **la elige quien invita** al crear la invitación (selector: 24 h / 7 días / 30 días / fecha personalizada).

> Decisión de producto ya tomada (2026-09-10, `Acceso_prueba_dev.txt`): "Las cuentas se crean por invitación del propietario del grupo (fase P1)". Esta spec es esa fase P1 + la regla nueva de Juan (2026-09-16): *crear un círculo nuevo requiere autorización del administrador*.

---

## 1. Entorno y reglas no negociables

- Todo el trabajo contra **dev** (`nvannetdrfybowwjqqhf`). **Prod (`wmidlrhbkpzaepkybxjk`, 23 usuarios reales) queda fuera** hasta validación del test.
- La app habla **directo con Supabase** (auth + REST + RLS). No resucitar sentinel-api para esto.
- Ninguna clave en el cliente. La lógica privilegiada (validar token, crear membership, aprobar círculo) va en **RPC `security definer`** o edge function. Service key NUNCA en la app.
- **No debilitar RLS bajo ningún concepto.** Policies nuevas, ninguna existente se toca.
- Evidencia obligatoria por entrega: SQL de verificación (tablas + policies) y capturas/build de cada flujo. Sin evidencia no se da por hecho.

## 2. Modelo de datos (migración dev)

### 2.1 Tabla `invitations`
| columna | tipo | notas |
|---|---|---|
| id | uuid pk | default gen_random_uuid() |
| group_id | uuid → groups | not null |
| inviter_user_id | uuid → profiles | not null |
| invitee_name | text | nombre de cortesía para el saludo |
| token | uuid unique | default gen_random_uuid(), va en el link |
| membership | text | check in ('fixed','temporary') |
| role | text | default 'member'; check in ('member','guest') |
| expires_at | timestamptz | obligatorio si membership='temporary' |
| status | text | default 'pending'; check in ('pending','accepted','declined','expired','revoked') |
| accepted_by | uuid → profiles | null hasta aceptar |
| created_at / accepted_at | timestamptz | |

**RLS (4 policies, patrón `saved_places`/`zones_admin_insert`):**
- `invitations_admin_select`: select si el usuario es owner/admin del grupo (`exists` sobre group_members).
- `invitations_admin_insert`: insert si owner/admin del grupo.
- `invitations_admin_update`: update solo para revocar (status → 'revoked'), owner/admin.
- La aceptación NO usa policy directa: va por RPC (2.3).

### 2.2 Tabla `circle_requests`
| columna | tipo | notas |
|---|---|---|
| id | uuid pk | |
| requester_user_id | uuid → profiles | not null |
| group_id | uuid → groups | círculo actual del solicitante (de cuyo admin depende) |
| desired_name | text | nombre que quiere para su círculo |
| status | text | default 'pending'; check in ('pending','approved','denied') |
| decided_by / decided_at | uuid / timestamptz | |
| created_at | timestamptz | |

**RLS:** insert solo si eres miembro activo de `group_id`; select si eres el solicitante o owner/admin del grupo; update (decidir) solo owner/admin del grupo. Un `unique partial index` sobre `(requester_user_id) where status='pending'` impide spam de solicitudes.

### 2.3 RPC `security definer`
- `accept_invitation(p_token uuid)` → valida token (existe, status='pending', no expirado), crea el membership (rol + membership + expiración heredada de la invitación), marca la invitación 'accepted' con accepted_by = auth.uid(). Devuelve group_id + nombre del grupo. Si el usuario no tiene sesión, el cliente primero hace signUp de Supabase auth y luego llama al RPC.
- `decide_circle_request(p_request_id uuid, p_approve boolean, p_new_group_name text default null)` → si aprueba: crea el grupo nuevo (owner = solicitante), mueve al solicitante al nuevo grupo (ver decisión D2), marca 'approved'. Si deniega: marca 'denied'. Solo owner/admin del grupo origen (validado dentro del RPC).
- `expire_temporary_memberships()` → job programado (pg_cron o edge function diaria): memberships temporales vencidas → status 'expired'; invitaciones vencidas → 'expired'.

## 3. Flujos (UX)

### 3.1 Invitar (owner/admin) — reactivar código existente
- Punto de entrada: botón "Invitar" en `app/(tabs)/grupo.tsx` (hoy no existe; la pantalla es de solo lectura).
- Hoja de invitación: ya existe `src/components/sheets.tsx` (nombre, fijo/temporal "Invitado temporal · Con expiración", canal WhatsApp/SMS/enlace). **Está huérfana: cablearla.**
- Si elige temporal: **selector de duración a elección del invitador** (D4): chips 24 h / 7 días / 30 días / fecha personalizada → rellena `expires_at`. Sin duración elegida no se puede enviar.
- `src/invites.ts` (dispatch por WhatsApp/SMS con etiquetas honestas) existe pero llama a `src/api.ts` (capa muerta): **portar a Supabase** (insert en `invitations` + link `https://<web-dev>/unirse/{token}`).

### 3.2 Aceptar invitación — onboarding personalizado del círculo (lo que Juan quiere ver)
Ruta nueva `app/unirse/[token].tsx` (la antigua `src/_retired/invite/[token].tsx` sirve de referencia visual, no de lógica):
1. **Pantalla de bienvenida personalizada**: nombre del círculo ("Familia Centro Madrid"), quién te invita ("Juan te ha invitado"), si es fijo o temporal ("Invitación temporal · acceso hasta el {fecha}"), y qué verán los demás (tu posición cuando la compartas, tu nombre). Referencia de diseño: flujo join de repo200 (`MobileJoin.jsx`: nombre + color de avatar de una paleta), portado a Supabase.
2. Botón **"Unirme al círculo de {nombre}"** → signUp (email + contraseña) → consentimientos (`REQUIRED_DOCS` ya existe en `src/lib/sentinel.tsx`) → perfil mínimo (nombre visible + color/símbolo de avatar) → RPC `accept_invitation` → entra directo a `(tabs)/mapa` con el grupo cargado.
3. Si el token está usado/expirado/revocado: pantalla honesta ("Esta invitación ya no es válida · pide una nueva a quien te la envió"). Nunca simular éxito.

### 3.3 Crear círculo nuevo — autorización del administrador (REGLA NUEVA DE JUAN)
- Entrada: en Perfil, opción "Crear mi propio círculo".
- **Popup (copy literal de Juan):** "Para crear tu círculo necesitas autorización del administrador" + campo nombre del círculo + **botón Enviar**.
- Al enviar: insert en `circle_requests` → evento visible para owner/admin (feed de Actividad + badge en Grupo).
- **Bandeja del admin** (sección nueva en `grupo.tsx`, visible solo a owner/admin): solicitud con nombre del solicitante y del círculo pedido, botones **Aceptar** / **Denegar** → RPC `decide_circle_request`.
- Resultado para el solicitante: estado en Perfil ("Solicitud enviada · pendiente", "¡Aceptada! Ya eres administrador de {nombre}", "Denegada por el administrador").

## 4. El test de Juan (script de aceptación, 6 miembros + Juan)

**Regla de oro del test (Juan, 2026-09-16): los 5 testers hacen su propio signup a través del flujo de invitación. PROHIBIDO crear sus cuentas por SQL, Admin API o semilla.** La única cuenta preexistente es la de Juan (`juan@sentinel.dev`, owner bootstrap del primer círculo — alguien tiene que ser el primer owner; no hay otra vía sin romper la regla "cuentas solo por invitación").

Cuentas (D3, 6 en total): Juan = owner del círculo "Familia Centro Madrid" + **5 invitados: 2 fijos (F1, F2) y 3 temporales (T1, T2, T3)** con duraciones distintas elegidas por quien invita (D4) — p. ej. T1 a 24 h, T2 a 7 días, T3 a 30 días, para probar el selector.

**Paso 0 — Preparación dev (antes de invitar):** retirar del círculo "Familia Centro Madrid" las membresías semilla (María, Lucía, Abuelo Pedro) para que el círculo arranque solo con Juan. Es dev, reversible, y NO cuenta como "crear usuarios": solo limpia el escenario. Evidencia: `select count(*) from group_members where group_id=...` antes (5) y después (1).

| # | Paso | Actor | Evidencia exigida |
|---|---|---|---|
| 1 | Juan invita a F1 y F2 (fijos) por enlace | owner | fila `invitations` + captura del link |
| 2 | Juan promueve a F1 a admin; **F1 invita a T1** (un miembro envía el link, como pediste; T1 temporal a 24 h elegido por F1) | F1 | captura hoja de invitación de F1 con selector de duración |
| 3 | Juan invita a T2 (7 días) y T3 (30 días) | owner | 2 filas con `membership='temporary'` y `expires_at` distintos |
| 4 | Cada invitado abre su link, hace **signup** y el **onboarding personalizado** | 5 invitados | captura de bienvenida + perfil + entrada al mapa |
| 5 | T1 intenta **crear círculo nuevo** → popup de autorización → Enviar | T1 | captura popup + fila `circle_requests` |
| 6 | Juan **deniega** a T1 y **acepta** a F2 (que también lo pide) | owner | captura bandeja + estados finales |
| 7 | F2 **se mueve** a su nuevo círculo como owner (D2: ya no aparece en el de Juan); T1 recibe "Denegada" | sistema | SQL de verificación + capturas |
| 8 | Forzar expiración de T3 (fecha al pasado en dev) → pasa a 'expired' y pierde acceso | sistema | SQL + captura de su pantalla |

**Criterio de aprobado del test:** paso 0 + los 8 pasos con evidencia, **0 cuentas de tester creadas por SQL/Admin API — los 5 testers nacen de un link de invitación y su propio signup**, 0 errores de consola en el flujo.

## 5. Decisiones — RESUELTAS (2026-09-16)

- **D1 — Alcance:** ✅ Aprobado. P1 completa (2.1–3.3) entra en cola de Rocket.
- **D2 — Círculo nuevo aprobado:** el solicitante **se mueve** al nuevo círculo como owner. Multi-grupo → P2.
- **D3 — Cuentas del test:** 6 en total (Juan + 5 invitados: 2 fijos, 3 temporales).
- **D4 — Expiración temporal:** **a elección de quien invita** (selector 24 h / 7 días / 30 días / fecha personalizada). Aviso al admin cuando una membresía temporal caduca.

## 6. Fuera de alcance (para que nadie lo "arregle" por accidente)

Multi-grupo, billing/planes, geocercas en background (R-02), Mapbox (R-04), convoy (P2 del backlog), prod.
