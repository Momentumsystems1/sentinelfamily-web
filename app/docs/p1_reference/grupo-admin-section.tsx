// P1 — Secciones para app/(tabs)/grupo.tsx (spec 3.1 y 3.3)
// 1) Botón "Invitar" + cableado de AddMemberSheet (hoy huérfana en src/components/sheets.tsx)
// 2) Bandeja del admin: solicitudes de círculo nuevo con Aceptar / Denegar
// INTEGRACIÓN: adaptar imports; el selector de duración D4 va en AddMemberSheet (ver INTEGRACION.md).
import React, { useCallback, useEffect, useState } from "react";
import { View } from "react-native";

import { supabase } from "@/src/lib/sentinel"; // <-- adaptar
import { AddMemberSheet, NewInvite } from "@/src/components/sheets"; // ya existe (huérfana)
import { Button, T } from "@/src/components/ui"; // <-- adaptar
import { createInvitation, dispatchInvitation } from "@/src/invites"; // port Supabase (invites.supabase.ts)
import { spacing, useTheme } from "@/src/theme"; // <-- adaptar

// ---------- 3.1 Invitar ----------
export function InviteSection({ groupId, isAdmin }: { groupId: string; isAdmin: boolean }) {
  const [sheetOpen, setSheetOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  if (!isAdmin) return null;

  // D4: NewInvite debe llevar expiresAt ISO (24h / 7d / 30d / fecha personalizada) — ver INTEGRACION.md
  async function onSubmit(v: NewInvite & { expiresAt?: string | null }) {
    setLoading(true);
    setFeedback(null);
    const res = await createInvitation({
      groupId,
      inviteeName: v.name,
      membership: v.membership,
      role: "member",
      expiresAt: v.membership === "temporary" ? v.expiresAt : null,
    });
    if (!res.ok) {
      setFeedback(res.label);
      setLoading(false);
      return;
    }
    const d = await dispatchInvitation(res.invitation, v.channel === "sms" ? "sms" : "whatsapp");
    setFeedback(d.label);
    setLoading(false);
    if (d.ok) setSheetOpen(false);
  }

  return (
    <View style={{ marginTop: spacing.lg }}>
      <Button title="Invitar" onPress={() => setSheetOpen(true)} />
      {feedback ? <T style={{ marginTop: spacing.sm }}>{feedback}</T> : null}
      <AddMemberSheet visible={sheetOpen} onClose={() => setSheetOpen(false)} onSubmit={onSubmit} loading={loading} />
    </View>
  );
}

// ---------- 3.3 Bandeja del admin (solicitudes de círculo nuevo) ----------
type CircleRequest = {
  id: string;
  desired_name: string;
  status: "pending" | "approved" | "denied";
  created_at: string;
  requester: { display_name: string | null } | null;
};

export function CircleRequestsInbox({ groupId, isAdmin }: { groupId: string; isAdmin: boolean }) {
  const { colors } = useTheme();
  const [requests, setRequests] = useState<CircleRequest[]>([]);
  const [feedback, setFeedback] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!isAdmin) return;
    const { data } = await supabase
      .from("circle_requests")
      .select("id, desired_name, status, created_at, requester:profiles!circle_requests_requester_user_id_fkey(display_name)")
      .eq("group_id", groupId)
      .eq("status", "pending")
      .order("created_at", { ascending: true });
    setRequests((data as CircleRequest[]) ?? []);
  }, [groupId, isAdmin]);

  useEffect(() => {
    load();
  }, [load]);

  async function decide(id: string, approve: boolean) {
    setFeedback(null);
    const { data, error } = await supabase.rpc("decide_circle_request", {
      p_request_id: id,
      p_approve: approve,
    });
    if (error || data?.error) {
      setFeedback("No se pudo procesar la solicitud (" + (data?.error ?? error?.message) + ")");
      return;
    }
    setFeedback(approve ? "Solicitud aceptada" : "Solicitud denegada");
    load();
  }

  if (!isAdmin || requests.length === 0) return null;

  return (
    <View style={{ marginTop: spacing.xl }}>
      <T weight="bold" style={{ fontSize: 18 }}>Solicitudes de círculo nuevo</T>
      {requests.map((r) => (
        <View
          key={r.id}
          style={{ marginTop: spacing.md, padding: spacing.md, borderWidth: 1, borderColor: colors.border, borderRadius: 12 }}
        >
          <T weight="semibold">{r.requester?.display_name ?? "Miembro"}</T>
          <T style={{ color: colors.muted, marginTop: 2 }}>Quiere crear el círculo “{r.desired_name}”</T>
          <View style={{ flexDirection: "row", gap: spacing.sm, marginTop: spacing.md }}>
            <Button title="Aceptar" onPress={() => decide(r.id, true)} />
            <Button title="Denegar" variant="secondary" onPress={() => decide(r.id, false)} />
          </View>
        </View>
      ))}
      {feedback ? <T style={{ marginTop: spacing.sm }}>{feedback}</T> : null}
    </View>
  );
}
