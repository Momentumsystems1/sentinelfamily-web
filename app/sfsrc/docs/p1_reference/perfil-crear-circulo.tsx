// P1 — Perfil: "Crear mi propio círculo" (spec 3.3, REGLA NUEVA DE JUAN)
// Popup con copy LITERAL de Juan + estado de la solicitud para el solicitante.
// INTEGRACIÓN: montar en la pantalla de Perfil de v2.2.0; adaptar imports.
import React, { useCallback, useEffect, useState } from "react";
import { Modal, Pressable, TextInput, View } from "react-native";

import { supabase } from "@/src/lib/sentinel"; // <-- adaptar
import { Button, T } from "@/src/components/ui"; // <-- adaptar
import { spacing, useTheme } from "@/src/theme"; // <-- adaptar

export function CreateCircleSection({ groupId }: { groupId: string }) {
  const { colors } = useTheme();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState("");
  const [sending, setSending] = useState(false);
  const [myRequest, setMyRequest] = useState<{ status: string; desired_name: string } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const { data: userData } = await supabase.auth.getUser();
    const userId = userData.user?.id;
    if (!userId) return;
    const { data } = await supabase
      .from("circle_requests")
      .select("status, desired_name")
      .eq("requester_user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    setMyRequest(data);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function send() {
    setSending(true);
    setError(null);
    const { data: userData } = await supabase.auth.getUser();
    const userId = userData.user?.id;
    if (!userId) {
      setError("Sesión no válida");
      setSending(false);
      return;
    }
    const { error: insertError } = await supabase.from("circle_requests").insert({
      requester_user_id: userId,
      group_id: groupId,
      desired_name: name.trim(),
    });
    setSending(false);
    if (insertError) {
      // unique partial index: ya hay una pendiente
      setError(
        insertError.code === "23505"
          ? "Ya tienes una solicitud pendiente"
          : "No se pudo enviar la solicitud"
      );
      return;
    }
    setOpen(false);
    setName("");
    load();
  }

  return (
    <View style={{ marginTop: spacing.xl }}>
      <Button title="Crear mi propio círculo" variant="secondary" onPress={() => setOpen(true)} />

      {myRequest?.status === "pending" ? (
        <T style={{ marginTop: spacing.sm, color: colors.muted }}>Solicitud enviada · pendiente</T>
      ) : null}
      {myRequest?.status === "approved" ? (
        <T style={{ marginTop: spacing.sm }}>¡Aceptada! Ya eres administrador de {myRequest.desired_name}</T>
      ) : null}
      {myRequest?.status === "denied" ? (
        <T style={{ marginTop: spacing.sm, color: colors.muted }}>Denegada por el administrador</T>
      ) : null}

      <Modal visible={open} transparent animationType="fade" onRequestClose={() => setOpen(false)}>
        <Pressable
          style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.5)", justifyContent: "center", padding: spacing.xl }}
          onPress={() => setOpen(false)}
        >
          <Pressable
            style={{ backgroundColor: colors.surface, borderRadius: 16, padding: spacing.xl }}
            onPress={(e) => e.stopPropagation()}
          >
            {/* COPY LITERAL DE JUAN — no cambiar ni una coma */}
            <T weight="bold" style={{ fontSize: 18 }}>
              Para crear tu círculo necesitas autorización del administrador
            </T>
            <TextInput
              placeholder="Nombre del círculo"
              placeholderTextColor={colors.muted}
              value={name}
              onChangeText={setName}
              style={{
                marginTop: spacing.lg, borderWidth: 1, borderColor: colors.border,
                borderRadius: 12, padding: spacing.md, color: colors.onSurface,
              }}
            />
            {error ? <T style={{ color: colors.danger, marginTop: spacing.md }}>{error}</T> : null}
            <Button title="Enviar" onPress={send} disabled={!name.trim() || sending} style={{ marginTop: spacing.xl }} />
          </Pressable>
        </Pressable>
      </Modal>
    </View>
  );
}
