// P1 — Port de src/invites.ts a Supabase (sustituye la capa muerta src/api.ts)
// Spec P1 §3.1. Mantiene las etiquetas honestas del dispatch original.
// INTEGRACIÓN: ajusta el import de `supabase` a donde viva el cliente en v2.2.0
// (probablemente src/lib/sentinel.tsx) y EXPO_PUBLIC_WEB_BASE_URL al dominio web dev.
import * as SMS from "expo-sms";
import { Linking, Platform } from "react-native";

import { supabase } from "@/src/lib/sentinel"; // <-- adaptar si el cliente vive en otro módulo

const WEB_BASE = process.env.EXPO_PUBLIC_WEB_BASE_URL ?? "https://<web-dev>"; // <-- dominio web dev real

export type Membership = "fixed" | "temporary";

export type Invitation = {
  token: string;
  name: string;
  channel: "whatsapp" | "sms" | "link";
  status: string;
  link: string;
  group_name: string;
  membership: Membership;
  expires_at?: string | null;
};

export function buildInviteLink(token: string) {
  return `${WEB_BASE}/unirse/${token}`;
}

/** Crea la invitación en Supabase (spec 2.1). El invitador debe ser owner/admin (RLS). */
export async function createInvitation(input: {
  groupId: string;
  inviteeName: string;
  membership: Membership;
  role?: "member" | "guest";
  expiresAt?: string | null; // ISO; OBLIGATORIO si membership === 'temporary' (D4)
}): Promise<{ ok: true; invitation: Invitation } | { ok: false; label: string }> {
  if (input.membership === "temporary" && !input.expiresAt) {
    return { ok: false, label: "Elige una duración para el invitado temporal" };
  }
  const { data: userData } = await supabase.auth.getUser();
  const userId = userData.user?.id;
  if (!userId) return { ok: false, label: "Sesión no válida" };

  const { data, error } = await supabase
    .from("invitations")
    .insert({
      group_id: input.groupId,
      invited_by: userId,
      invitee_name: input.inviteeName,
      membership: input.membership,
      role: input.role ?? "member",
      expires_at: input.membership === "temporary" ? input.expiresAt : null,
      status: "pending",
    })
    .select("token")
    .single();

  if (error || !data) return { ok: false, label: "No se pudo crear la invitación" };

  const { data: group } = await supabase
    .from("groups")
    .select("name")
    .eq("id", input.groupId)
    .single();

  return {
    ok: true,
    invitation: {
      token: data.token,
      name: input.inviteeName,
      channel: "link",
      status: "pending",
      link: buildInviteLink(data.token),
      group_name: group?.name ?? "tu círculo",
      membership: input.membership,
      expires_at: input.expiresAt ?? null,
    },
  };
}

export function inviteText(inv: Invitation) {
  const expiry =
    inv.membership === "temporary" && inv.expires_at
      ? ` (acceso hasta el ${new Date(inv.expires_at).toLocaleDateString("es-ES")})`
      : "";
  return `Hola ${inv.name}, te invito a mi círculo "${inv.group_name}" en Sentinel Family${expiry}. Abre este enlace para unirte: ${inv.link}`;
}

/** Dispatch por WhatsApp/SMS con etiquetas honestas. Nunca "enviado" sin confirmación del SO. */
export async function dispatchInvitation(
  inv: Invitation,
  channel: "whatsapp" | "sms"
): Promise<{ ok: boolean; label: string }> {
  const text = inviteText(inv);
  const markDispatched = () =>
    supabase.from("invitations").update({ status: "dispatched" }).eq("token", inv.token);
  try {
    if (channel === "whatsapp") {
      const url = `https://wa.me/?text=${encodeURIComponent(text)}`;
      const can = Platform.OS === "web" ? true : await Linking.canOpenURL(url).catch(() => true);
      if (!can) return { ok: false, label: "WhatsApp no disponible en este dispositivo" };
      await Linking.openURL(url);
      await markDispatched();
      return { ok: true, label: "Invitación preparada en WhatsApp" };
    }
    if (Platform.OS !== "web" && (await SMS.isAvailableAsync())) {
      const r = await SMS.sendSMSAsync([], text);
      if (r.result === "sent") {
        await markDispatched();
        return { ok: true, label: "SMS enviado (confirmado por el sistema)" };
      }
      if (r.result === "cancelled") return { ok: false, label: "Envío de SMS cancelado" };
      await markDispatched();
      return { ok: true, label: "Invitación preparada (estado de entrega desconocido)" };
    }
    await Linking.openURL(`sms:?&body=${encodeURIComponent(text)}`);
    await markDispatched();
    return { ok: true, label: "Invitación preparada" };
  } catch {
    return { ok: false, label: "No se pudo abrir el canal de invitación" };
  }
}

/** Revocar (spec 2.1: update solo a 'revoked', owner/admin). */
export async function revokeInvitation(token: string) {
  return supabase.from("invitations").update({ status: "revoked" }).eq("token", token);
}
