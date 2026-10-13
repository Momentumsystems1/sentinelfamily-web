# Sentinel Family — Engineering Handoff

**Version:** baseline/rocket-handoff-v1  
**Date:** 2026-09-08  
**Prepared by:** Rocket.new automated handoff  
**Target repo:** Momentumsystems1/sentinel-family-flutter  

---

## 1. Architecture Overview

Sentinel Family is a Flutter application for real-time family/group location sharing. It uses Supabase as the sole backend (auth, database, realtime, storage) and Mapbox for native map rendering with a flutter_map fallback for web/preview.

```
sentinelfamily/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── core/app_export.dart               # Barrel exports (packages + shared widgets)
│   ├── theme/app_theme.dart               # Material 3 theme (light + dark)
│   ├── routes/app_routes.dart             # GoRouter configuration
│   ├── services/
│   │   ├── supabase_service.dart          # All Supabase operations (singleton)
│   │   ├── group_change_notifier.dart     # ChangeNotifier for group membership events
│   │   └── traffic/                       # Traffic incident architecture (STUB — not implemented)
│   │       ├── traffic_incident.dart
│   │       ├── traffic_incident_provider.dart
│   │       └── providers/                 # Azure, DGT, SCT, Mapbox stubs
│   ├── presentation/
│   │   ├── onboarding_screen/             # Consent + administrator onboarding
│   │   ├── sign_up_login_screen/          # Email/password auth
│   │   ├── live_map_screen/               # Main map screen
│   │   │   ├── live_map_screen.dart
│   │   │   ├── map_renderer/
│   │   │   │   ├── sentinel_map_renderer.dart   # Abstract interface + factory
│   │   │   │   ├── mapbox_map_renderer.dart     # Native Android/iOS renderer
│   │   │   │   └── web_map_renderer.dart        # Web/preview flutter_map renderer
│   │   │   └── widgets/
│   │   │       ├── person_map_object_widget.dart # PersonMapObject marker
│   │   │       ├── person_detail_sheet.dart      # Unified member detail sheet
│   │   │       ├── member_avatar_strip_widget.dart
│   │   │       ├── map_group_selector_widget.dart
│   │   │       ├── ghost_mode_chip_widget.dart
│   │   │       ├── sos_fab_widget.dart
│   │   │       └── ...
│   │   ├── groups_screen/                 # Group management
│   │   ├── alerts_screen/                 # Alert history
│   │   ├── profile_screen/                # User profile + privacy settings
│   │   └── join_invitation_screen/        # Invitation acceptance
│   └── widgets/                           # Shared widgets
│       ├── app_scaffold.dart
│       ├── app_navigation.dart
│       ├── empty_state_widget.dart
│       └── ...
├── supabase/migrations/                   # All DB migrations in chronological order
├── assets/images/                         # SVG/image assets
├── android/                               # Android project
├── ios/                                   # iOS project
├── web/                                   # Web project
├── pubspec.yaml
├── .env.example                           # Environment variable template
└── docs/
    ├── HANDOFF.md                         # This file
    └── PRODUCT_STATE.md                   # Feature completion status
```

---

## 2. App Entry Point

`lib/main.dart`

- Initializes Supabase via `SupabaseService.initialize()`
- Locks orientation to portrait
- Configures custom error widget
- Runs `MyApp` with GoRouter

---

## 3. Navigation

Router: `go_router ^14.6.1`  
Config: `lib/routes/app_routes.dart`

| Route | Screen | Notes |
|---|---|---|
| `/` | OnboardingScreen | Redirects to map if authenticated |
| `/onboarding-screen` | OnboardingScreen | Same as `/` |
| `/sign-up-login-screen` | SignUpLoginScreen | Email/password auth |
| `/live-map-screen` | LiveMapScreen | Main screen (requires auth) |
| `/groups-screen` | GroupsScreen | Group management |
| `/alerts-screen` | AlertsScreen | Alert history |
| `/profile-screen` | ProfileScreen | User profile |
| `/join/:token` | JoinInvitationScreen | Invitation acceptance (works unauthenticated) |

Bottom navigation: `AppNavigation` (4 tabs: Map, Groups, Alerts, Profile)

**Auth redirect logic:** Authenticated users on `/` or `/sign-up-login-screen` are redirected to `/live-map-screen`. `/join/:token` bypasses auth redirect.

---

## 4. Supabase Integration

**Client:** `supabase_flutter ^2.9.1`  
**Service:** `lib/services/supabase_service.dart` (singleton)

All Supabase operations are centralized in `SupabaseService`. The client is accessed via `SupabaseService.instance.client`.

### Initialization

```dart
await SupabaseService.initialize();
// Reads SUPABASE_URL and SUPABASE_ANON_KEY from --dart-define
```

### Key Methods

| Method | Purpose |
|---|---|
| `signUp / signIn / signOut` | Auth |
| `getProfile / updateProfile` | Profile CRUD |
| `getMyGroups()` | Returns groups + members for current user |
| `createGroupAsOwner(name, description)` | Atomic RPC — creates group + owner membership |
| `canCreateGroups()` | Checks `profiles.can_create_groups` |
| `grantCanCreateGroups()` | Grants admin capability (onboarding path) |
| `createInvitation(groupId, contact)` | Creates invitation (admin only via RLS) |
| `acceptInvitationAtomic(token)` | Atomic RPC — validates + joins + marks accepted |
| `getGroupLocations(groupId)` | Fetches member locations |
| `upsertLocation(groupId, lat, lng)` | Writes own location |
| `subscribeToGroupLocations(groupId, cb)` | Realtime location subscription |
| `getMyAlerts() / createAlert()` | Alert CRUD |
| `subscribeToAlerts(groupIds, cb)` | Realtime alert subscription |

---

## 5. Current Database Schema

Schema is the result of all migrations applied in order. See `supabase/migrations/` for full SQL.

### `public.profiles`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | References `auth.users(id)` |
| `display_name` | TEXT | |
| `phone` | TEXT | |
| `avatar_color` | TEXT | Hex color string |
| `avatar_symbol` | TEXT | |
| `avatar_url` | TEXT | Added in migration 080000 |
| `can_create_groups` | BOOLEAN NOT NULL DEFAULT FALSE | Added in migration 140000 |
| `created_at` | TIMESTAMPTZ | |

### `public.groups`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `name` | TEXT NOT NULL | |
| `owner_id` | UUID | References `profiles(id)` |
| `created_at` | TIMESTAMPTZ | |

### `public.group_members`

| Column | Type | Notes |
|---|---|---|
| `id` | SERIAL PK (assumed) | |
| `group_id` | UUID | References `groups(id)` |
| `user_id` | UUID | References `profiles(id)` |
| `role` | TEXT | `'owner'`, `'admin'`, `'member'` |
| `status` | TEXT | `'active'`, `'inactive'` |
| `created_at` | TIMESTAMPTZ | |

### `public.invitations`

| Column | Type | Notes |
|---|---|---|
| `token` | UUID PK | Generated by `gen_random_uuid()` default |
| `group_id` | UUID | References `groups(id)` |
| `invited_by` | UUID | References `profiles(id)` |
| `contact` | TEXT | Optional email/phone |
| `status` | TEXT | `'prepared'`, `'pending'`, `'dispatched'`, `'accepted'`, `'expired'`, `'revoked'` |
| `created_at` | TIMESTAMPTZ | |

### `public.locations`

| Column | Type | Notes |
|---|---|---|
| `user_id` | UUID | References `profiles(id)` |
| `group_id` | UUID | References `groups(id)` |
| `lat` | FLOAT8 | |
| `lng` | FLOAT8 | |
| `accuracy` | FLOAT8 | |
| `battery` | INT | |
| `updated_at` | TIMESTAMPTZ | |

Primary key is `(user_id, group_id)` (upsert target).

### `public.alert_events`

| Column | Type | Notes |
|---|---|---|
| `id` | SERIAL PK | |
| `user_id` | UUID | References `profiles(id)` |
| `group_id` | UUID | References `groups(id)` |
| `kind` | TEXT | `'emergency'`, `'ok_check'`, `'incident'` |
| `status` | TEXT | `'open'`, `'private_warning'`, `'escalated'`, `'resolved'` |
| `lat` | FLOAT8 | |
| `lng` | FLOAT8 | |
| `target_user_id` | UUID | Added in migration 090000. References `profiles(id)` ON DELETE SET NULL |
| `created_at` | TIMESTAMPTZ | |

---

## 6. Migrations (Chronological)

| File | Purpose |
|---|---|
| `20260908080000_add_avatar_url_to_profiles.sql` | Adds `avatar_url` to profiles; storage RLS for avatars bucket |
| `20260908090000_add_target_user_id_to_alert_events.sql` | Adds `target_user_id` to alert_events for directed ok_check |
| `20260908130000_fix_invitation_rls_and_rpc.sql` | `accept_invitation` RPC; `is_group_admin` helper; RLS for groups, group_members, invitations |
| `20260908140000_create_group_as_owner_rpc.sql` | `can_create_groups` column; `create_group_as_owner` RPC; `grant_can_create_groups` helper; profiles RLS |
| `20260908150000_fix_admin_provisioning.sql` | Provisions earliest user as admin; `block_can_create_groups_self_update` trigger; updated `accept_invitation` RPC; `handle_new_user_provisioning` trigger |

**No corrective migration required.** Code and schema are consistent as of this handoff.

---

## 7. Authentication Flow

1. **New administrator:** Onboarding screen → `signUp()` → `grantCanCreateGroups()` → map
2. **Returning user:** Sign-in screen → `signIn()` → map
3. **Invited member:** `/join/:token` → optionally sign up/in → `acceptInvitationAtomic(token)` → map (group auto-selected)

**`can_create_groups` provisioning:**
- Standalone signup → `TRUE` (set by `handle_new_user_provisioning` trigger on `auth.users`)
- Invitation acceptance → `FALSE` (set explicitly by `accept_invitation` RPC)
- Primary admin bootstrap → `TRUE` (set by migration 150000 DO block)

---

## 8. Group / Invitation Flow

### Create Group (Admin only)
```
GroupsScreen._showCreateGroupDialog()
→ SupabaseService.createGroupAsOwner(name, description)
→ RPC: create_group_as_owner (checks can_create_groups, atomic insert)
→ GroupChangeNotifier.notifyGroupsChangedWithActiveGroup(groupId)
→ LiveMapScreen auto-selects new group
```

### Invite Member (Admin only)
```
InviteSheetWidget
→ SupabaseService.createInvitation(groupId, contact)
→ Invitation row created (token = gen_random_uuid())
→ Share invitation URL: https://sentinelfa7804.builtwithrocket.new/join/{token}
```

### Accept Invitation
```
/join/:token → JoinInvitationScreen
→ SupabaseService.acceptInvitationAtomic(token)
→ RPC: accept_invitation (validates, inserts membership as role=member, marks accepted)
→ GroupChangeNotifier.notifyGroupsChangedWithActiveGroup(groupId)
→ Navigate to /live-map-screen
→ LiveMapScreen._onGroupsChanged() → _loadGroupsWithActiveId(groupId)
```

---

## 9. Map Architecture

### Renderer Abstraction

```
SentinelMapRenderer (abstract, lib/presentation/live_map_screen/map_renderer/sentinel_map_renderer.dart)
├── Android/iOS → MapboxMapRenderer (mapbox_map_renderer.dart)
│   - mapbox_maps_flutter ^2.30.0
│   - Style: mapbox://styles/mapbox/standard
│   - Follow Me: pitch 50°, heading-based bearing
│   - flyTo, fitBounds, coordinateToScreen
└── Web/Rocket Preview → WebMapRenderer (web_map_renderer.dart)
    - flutter_map ^8.3.2 + latlong2 ^0.10.1
    - OSM tiles (openstreetmap.org)
    - 2D only (pitch always 0)
    - Same interface as Mapbox renderer
```

Platform selection uses Dart conditional imports:
```dart
import 'mapbox_map_renderer.dart'
    if (dart.library.html) 'web_map_renderer.dart';
```

### Camera Modes
- `followMe` — camera tracks GPS with heading-based bearing (default)
- `free` — user has manually panned; camera does not follow GPS

### PersonMapObject Architecture

`PersonMapData` — data model for a person on the map:
- `userId`, `displayName`, `avatarColorHex`, `avatarUrl`
- `lat`, `lng`, `updatedAt`, `battery`
- `movementState` (moving/stopped/unknown — from real GPS speed)
- `activityState` (normal/route/meeting/convoy — route/meeting/convoy are future)
- `phone`, `shortAddress`

`PersonMapObjectWidget` — renders the marker:
- Fixed bounding box: 120×80px
- Anchor: center (60, 40) — maps to geographic coordinate
- Zoom-responsive scale via smooth interpolation
- Progressive capsule: photo-only (zoom<16), photo+name (16–17.5), full (>17.5)
- `Transform.scale(alignment: Alignment.center)` — anchor pixel never moves

`PersonDetailSheet` — unified bottom sheet:
- `isSelf=true`: edit profile, change photo (Supabase Storage), ¿Todo ok?, share location
- `isSelf=false`: read-only profile, ¿Todo bien? (creates alert_events with target_user_id), send message (phone/WhatsApp if available), share location

### GPS Jitter Filter
- Minimum movement threshold: `max(accuracy × 1.5, 8.0)` meters
- Maximum acceptable accuracy: 50m
- Location write throttle: 15 seconds

---

## 10. Environment Variables

All secrets are injected at compile time via `--dart-define`. See `.env.example`.

| Variable | Purpose | Required |
|---|---|---|
| `SUPABASE_URL` | Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | Yes |
| `MAPBOX_ACCESS_TOKEN` | Mapbox public token (pk.*) | Yes for native map |

**Removed from env.json:** `OPENAI_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, `PERPLEXITY_API_KEY` — these AI services are not used by the application.

---

## 11. Build Commands

### Prerequisites
- Flutter SDK ≥ 3.9.0
- Dart ≥ 3.2.0
- Android SDK (for Android builds)
- Xcode (for iOS builds)

### Install dependencies
```bash
flutter pub get
```

### Run (web/preview)
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

### Run (Android)
```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key> \
  --dart-define=MAPBOX_ACCESS_TOKEN=<token>
```

### Build APK (debug)
```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key> \
  --dart-define=MAPBOX_ACCESS_TOKEN=<token>
```

### Build APK (release)
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key> \
  --dart-define=MAPBOX_ACCESS_TOKEN=<token>
```

### Flutter analyze
```bash
flutter analyze
```

---

## 12. Known Bugs (P0 / P1)

### P0 — Blocking

| # | Description | Location | Status |
|---|---|---|---|
| P0-1 | `invitations` RLS `SELECT` for anon uses `USING (true)` — any anon user can read all invitations by token. Acceptable for MVP (token is a UUID secret) but should be tightened before production. | Migration 130000 | OPEN |
| P0-2 | `handle_new_user_provisioning` trigger sets `can_create_groups = TRUE` for ALL new signups, then `accept_invitation` RPC sets it back to `FALSE`. There is a race window between signup and invitation acceptance where the user briefly has `can_create_groups = TRUE`. | Migration 150000 | OPEN |

### P1 — Non-blocking

| # | Description | Location | Status |
|---|---|---|---|
| P1-1 | `joinGroup()` in `supabase_service.dart` is kept for backward compatibility but is unsafe (no RLS bypass). It will fail for invited members. Only `acceptInvitationAtomic()` should be used. | `supabase_service.dart:386` | OPEN — method should be removed or marked `@Deprecated` |
| P1-2 | `createGroup()` (non-RPC) is kept for backward compatibility but will fail if `can_create_groups = FALSE`. Should be removed. | `supabase_service.dart:262` | OPEN |
| P1-3 | `ProfileScreen` privacy toggles (`_locationExact`, `_locationBackground`, etc.) are local state only — not persisted to DB. | `profile_screen.dart` | OPEN |
| P1-4 | `OnboardingScreen` consent permissions are local state only — not persisted. | `onboarding_screen.dart` | OPEN |
| P1-5 | `AlertsScreen` realtime subscription passes empty `groupIds` list to `subscribeToAlerts()` — subscription listens to all `alert_events` changes, not filtered by group. | `alerts_screen.dart:66` | OPEN |
| P1-6 | `ProfileScreen` "Eliminar cuenta" button has empty `onPressed: () {}` — account deletion is not implemented. | `profile_screen.dart:378` | OPEN |

---

## 13. Unfinished Features

The following features have infrastructure present but are NOT implemented:

| Feature | Infrastructure Present | Missing |
|---|---|---|
| Traffic incidents | `TrafficIncidentProvider` interface + 4 stub providers | API credentials, HTTP calls, map layer rendering |
| Background location | `workmanager` package in pubspec | Background service implementation |
| Route history / Últimos movimientos | DB query stub in PersonDetailSheet | Actual `locations` history table + query |
| Convoy mode | `PersonActivityState.convoy` enum value | Backend, UI, logic |
| Quedada (meeting) mode | `PersonActivityState.meeting` enum value | Backend, UI, logic |
| Ghost mode timer | UI chip present, 30-min countdown | Timer does not actually expire; location is still written |
| Push notifications | `flutter_local_notifications` package | Notification triggers not implemented |
| Account deletion | Button present in ProfileScreen | Backend deletion + GDPR flow |
| Consent persistence | Onboarding consent UI | Consent not saved to DB |
| Privacy settings persistence | Profile screen toggles | Settings not saved to DB |
| Admin role assignment | `role = 'admin'` supported in DB | No UI to promote member to admin |
| Member removal | `group_members_delete` RLS policy | No UI to remove a member |
| Invitation expiry | `status = 'expired'` supported | No expiry timer/cron |
| Invitation revocation | `status = 'revoked'` supported | No UI to revoke a sent invitation |

---

## 14. Technical Debt

1. **State management:** No Riverpod/Bloc. All state is local `setState`. Comments in `onboarding_screen.dart` note this explicitly.
2. **`createGroup()` and `joinGroup()` legacy methods** should be removed from `supabase_service.dart` once confirmed unused.
3. **`profiles` RLS `SELECT` policy** only allows users to read their own profile. Group members cannot read each other's profiles directly — they receive profile data via joins in `getMyGroups()` and `getGroupLocations()`. This is intentional but limits future features.
4. **`invitations` table has no expiry mechanism.** Invitations remain valid indefinitely unless manually revoked.
5. **`locations` table has no cleanup.** Old location rows accumulate. A cron job or TTL policy is needed for production.
6. **No error boundary above `LiveMapScreen`.** A Mapbox initialization failure will show the custom error widget but not recover gracefully.
7. **`MapboxMapRenderer` `fitBounds` uses manual zoom calculation** instead of Mapbox's native `CameraFit`. This is a known approximation.
8. **`web_map_renderer.dart` `coordinateToScreen`** uses `latLngToScreenOffset` which may return incorrect values when the map is not fully rendered. Overlay positions may be slightly off on first render.

---

## 15. First-Admin Provisioning

The current implementation provisions the **earliest registered user** in `auth.users` as the primary admin (`can_create_groups = TRUE`) via a DO block in migration `20260908150000`. This is a one-time bootstrap.

**For production:** Replace this with an explicit admin invitation/provisioning flow. The current approach is fragile if the database is reset or if the earliest user is not the intended admin.

The `grant_can_create_groups(p_user_id UUID)` RPC is available for manual provisioning via Supabase dashboard SQL editor.

---

## 16. Repository

**Target:** `Momentumsystems1/sentinel-family-flutter`  
**Branch:** `baseline/rocket-handoff`  
**Tag:** `rocket-handoff-v1`

**Note:** Direct GitHub push is not supported in this environment. Export the project as a ZIP and commit manually.
