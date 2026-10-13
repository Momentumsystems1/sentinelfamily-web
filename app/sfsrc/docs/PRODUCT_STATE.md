# Sentinel Family — Product State

**Version:** baseline/rocket-handoff-v1  
**Date:** 2026-09-08  
**Legend:** WORKING | PARTIAL | NOT IMPLEMENTED | NOT TESTED

---

## Authentication

| Feature | State | Notes |
|---|---|---|
| Email/password sign up | WORKING | Tested in runtime |
| Email/password sign in | WORKING | Tested in runtime |
| Sign out | WORKING | |
| Auth state persistence (session) | WORKING | Supabase handles session |
| Auth redirect (unauthenticated → onboarding) | WORKING | GoRouter redirect |
| Auth redirect (authenticated → map) | WORKING | GoRouter redirect |
| Password reset | NOT IMPLEMENTED | No UI or email flow |
| Google Sign-In | NOT IMPLEMENTED | Package not included |
| Apple Sign-In | NOT IMPLEMENTED | Package not included |

---

## Onboarding

| Feature | State | Notes |
|---|---|---|
| Landing screen | WORKING | |
| Consent stepper (6 steps) | WORKING | UI only |
| Consent persistence to DB | NOT IMPLEMENTED | Permissions are local state only |
| Administrator provisioning on completion | WORKING | `grantCanCreateGroups()` called |

---

## Profiles

| Feature | State | Notes |
|---|---|---|
| Profile creation on signup | WORKING | `_upsertProfile()` called |
| Profile read | WORKING | |
| Profile update (name, phone) | WORKING | |
| Avatar color/symbol | PARTIAL | Stored in DB; no UI to change color/symbol in profile screen |
| Avatar photo upload | WORKING | Supabase Storage (avatars bucket) |
| Avatar photo display | WORKING | `CachedNetworkImage` |
| Privacy settings persistence | NOT IMPLEMENTED | Toggles are local state only |
| Account deletion | NOT IMPLEMENTED | Button present, `onPressed` is empty |

---

## Groups (Circles)

| Feature | State | Notes |
|---|---|---|
| Create group (admin only) | WORKING | Atomic RPC `create_group_as_owner` |
| List my groups | WORKING | |
| Group card display | WORKING | |
| Group member count | WORKING | |
| Admin/owner distinction | WORKING | `can_create_groups` + RLS |
| Member cannot create group | WORKING | RPC + RLS enforced |
| Group deletion | NOT IMPLEMENTED | No UI |
| Group rename | NOT IMPLEMENTED | No UI |
| Member removal | NOT IMPLEMENTED | No UI (RLS policy exists) |
| Admin role assignment | NOT IMPLEMENTED | No UI |

---

## Invitations

| Feature | State | Notes |
|---|---|---|
| Create invitation (admin only) | WORKING | RLS enforced |
| Share invitation link | WORKING | `share_plus` |
| Invitation acceptance (atomic) | WORKING | RPC `accept_invitation` |
| Duplicate membership prevention | WORKING | RPC checks existing membership |
| Invitation status tracking | WORKING | prepared/pending/dispatched/accepted/revoked |
| Invitation expiry | NOT IMPLEMENTED | No expiry timer |
| Invitation revocation UI | NOT IMPLEMENTED | Status supported in DB, no UI |
| Invitation list for admin | NOT IMPLEMENTED | No UI to see sent invitations |

---

## Map

| Feature | State | Notes |
|---|---|---|
| Web/preview map (flutter_map + OSM) | WORKING | |
| Native map (Mapbox Android/iOS) | WORKING | Requires MAPBOX_ACCESS_TOKEN |
| Follow Me camera mode | WORKING | Heading-based bearing, pitch 50° |
| Free camera mode | WORKING | Exits Follow Me on manual scroll |
| Zoom in/out controls | WORKING | |
| Fit all members | WORKING | |
| Own location marker | WORKING | |
| Other member markers | WORKING | |
| PersonMapObject (zoom-responsive) | WORKING | |
| Progressive capsule (photo/name/full) | WORKING | |
| PersonDetailSheet (self) | WORKING | Edit profile, change photo, share location |
| PersonDetailSheet (other member) | WORKING | ¿Todo bien?, send message, share location |
| Ghost mode (UI) | PARTIAL | Toggle works; location still written to DB; timer does not expire |
| Group selector | WORKING | |
| Member avatar strip | WORKING | |
| Empty state (no groups) | WORKING | |
| Map after invitation acceptance | WORKING | Auto-selects joined group |
| Traffic incidents layer | NOT IMPLEMENTED | Architecture present (stubs only) |
| Route display | NOT IMPLEMENTED | |

---

## Location

| Feature | State | Notes |
|---|---|---|
| Foreground GPS | WORKING | `geolocator` |
| GPS jitter filter | WORKING | Accuracy + distance threshold |
| Location write throttle (15s) | WORKING | |
| Location permission request | WORKING | |
| Location permission denied banner | WORKING | |
| Realtime location subscription | WORKING | Supabase realtime |
| Background location | NOT IMPLEMENTED | `workmanager` package present, no implementation |
| Location history | NOT IMPLEMENTED | Only latest position stored |

---

## Alerts (SOS / ¿Todo bien?)

| Feature | State | Notes |
|---|---|---|
| SOS alert creation | WORKING | Creates `alert_events` with kind=emergency |
| ¿Todo bien? alert creation | WORKING | Creates `alert_events` with kind=ok_check + target_user_id |
| Alert list screen | WORKING | |
| Alert filtering (all/emergency/checkin) | WORKING | |
| Alert summary bar | WORKING | |
| Alert chart | WORKING | |
| Alert acknowledge | WORKING | Updates status to private_warning |
| Alert escalate | WORKING | Updates status to escalated |
| Realtime alert subscription | PARTIAL | Subscription listens to all alert_events (not filtered by group) |
| Push notifications for alerts | NOT IMPLEMENTED | |

---

## Security / RLS

| Feature | State | Notes |
|---|---|---|
| `profiles` RLS (own read/write) | WORKING | |
| `can_create_groups` self-update blocked | WORKING | Trigger `trg_block_can_create_groups` |
| `groups` RLS (member read, admin write) | WORKING | |
| `group_members` RLS | WORKING | |
| `invitations` RLS (admin insert, anon read by token) | WORKING | Anon read is intentionally permissive |
| `locations` RLS | NOT TESTED | No explicit RLS migration found for locations table |
| `alert_events` RLS | NOT TESTED | No explicit RLS migration found for alert_events table |
| Backend enforcement of admin-only actions | WORKING | RPCs check `can_create_groups` and `is_group_admin()` |

---

## Infrastructure / Architecture

| Feature | State | Notes |
|---|---|---|
| SentinelMapRenderer abstraction | WORKING | |
| Conditional import (web vs native) | WORKING | |
| TrafficIncidentProvider interface | WORKING | Stubs only — no real data |
| GroupChangeNotifier | WORKING | |
| SupabaseService singleton | WORKING | |
| GoRouter navigation | WORKING | |
| Material 3 theme | WORKING | |
| Responsive design (Sizer) | WORKING | |

---

## Not Tested (Runtime)

The following were implemented but not verified with a real device/runtime test during this handoff:

- Background location service
- iOS build (Podfile present, not built)
- Mapbox token validation on first launch
- Invitation link opening from external app (deep link)
- Photo upload on Android (permissions)
- Realtime subscription reconnection after network loss
- `alert_events` and `locations` RLS policies (no migration found — may rely on Supabase defaults or pre-existing policies not in this migration set)
