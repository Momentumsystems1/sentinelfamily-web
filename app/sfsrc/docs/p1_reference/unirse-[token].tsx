// P1 — Ruta nueva app/unirse/[token].tsx (spec 3.2)
// Onboarding personalizado del círculo: bienvenida → signup → consentimientos →
// perfil mínimo → RPC accept_invitation → mapa.
// INTEGRACIÓN: adapta imports (supabase/REQUIRED_DOCS viven en src/lib/sentinel.tsx;
// componentes T/Button en src/components/ui.tsx; Sheet/theme como en el resto de la app).
// Referencia visual: src/_retired/invite/[token].tsx y MobileJoin.jsx de repo200.
import { useLocalSearchParams, useRouter } from "expo-router";
import React, { useEffect, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, TextInput, View } from "react-native";

import { supabase, REQUIRED_DOCS } from "@/src/lib/sentinel"; // <-- adaptar
import { Button, T } from "@/src/components/ui"; // <-- adaptar
import { spacing, useTheme } from "@/src/theme"; // <-- adaptar

const AVATAR_COLORS = ["#06AED5", "#F26430", "#7C5CBF", "#2E933C", "#D9A404", "#C3423F"];

type Preview = {
  group_name: string;
  inviter_name: string | null;
  invitee_name: string | null;
  membership: "fixed" | "temporary";
  expires_at: string | null;
};

type Step = "loading" | "invalid" | "welcome" | "signup" | "consents" | "profile" | "joining" | "done";

export default function UnirseScreen() {
  const { token } = useLocalSearchParams<{ token: string }>();
  const router = useRouter();
  const { colors } = useTheme();

  const [step, setStep] = useState<Step>("loading");
  const [preview, setPreview] = useState<Preview | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [acceptedDocs, setAcceptedDocs] = useState<Record<string, boolean>>({});
  const [displayName, setDisplayName] = useState("");
  const [avatarColor, setAvatarColor] = useState(AVATAR_COLORS[0]);

  // 1) Preview de la invitación (RPC security definer; el token ES el secreto)
  useEffect(() => {
    (async () => {
      const { data, error: rpcError } = await supabase.rpc("get_invitation_preview", { p_token: token });
      if (rpcError || !data || data.error) {
        setStep("invalid");
        return;
      }
      setPreview(data as Preview);
      if (data.invitee_name) setDisplayName(data.invitee_name);
      setStep("welcome");
    })();
  }, [token]);

  // 2) Signup (dev tiene mailer_autoconfirm=true → sesión inmediata)
  async function doSignup() {
    setError(null);
    setStep("joining");
    const { error: signUpError } = await supabase.auth.signUp({ email: email.trim(), password });
    if (signUpError) {
      setError("No se pudo crear la cuenta: " + signUpError.message);
      setStep("signup");
      return;
    }
    setStep("consents");
  }

  // 3) Consentimientos obligatorios (REQUIRED_DOCS ya existe en src/lib/sentinel.tsx)
  async function doConsents() {
    const { data: userData } = await supabase.auth.getUser();
    const userId = userData.user?.id;
    if (!userId) {
      setError("Sesión no válida");
      setStep("signup");
      return;
    }
    const rows = REQUIRED_DOCS.map((d: { id: string; version: string }) => ({
      user_id: userId,
      doc_id: d.id,
      doc_version: d.version,
      accepted_at: new Date().toISOString(),
    }));
    const { error: consentsError } = await supabase.from("consents").insert(rows);
    if (consentsError) {
      setError("No se pudieron registrar los consentimientos");
      return;
    }
    setStep("profile");
  }

  // 4) Perfil mínimo + 5) RPC accept_invitation → mapa
  async function doJoin() {
    setError(null);
    setStep("joining");
    const { data: userData } = await supabase.auth.getUser();
    const userId = userData.user?.id;
    if (!userId) {
      setError("Sesión no válida");
      setStep("signup");
      return;
    }
    await supabase.from("profiles").upsert({
      id: userId,
      display_name: displayName.trim(),
      avatar_color: avatarColor,
    });

    const { data, error: rpcError } = await supabase.rpc("accept_invitation", { p_token: token });
    if (rpcError || !data || data.error) {
      const code = data?.error ?? "unknown";
      if (code === "already_accepted" || code === "invitation_expired" || code === "invitation_revoked") {
        setStep("invalid");
        return;
      }
      setError("No se pudo completar la unión (" + code + ")");
      setStep("welcome");
      return;
    }
    setStep("done");
    router.replace("/(tabs)/mapa"); // <-- ruta del mapa en v2.2.0
  }

  if (step === "loading" || step === "joining") {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: colors.bg }}>
        <ActivityIndicator />
        <T style={{ marginTop: spacing.md }}>{step === "joining" ? "Un momento…" : "Cargando invitación…"}</T>
      </View>
    );
  }

  // Pantalla honesta: token usado / expirado / revocado (spec 3.2.3). Nunca simular éxito.
  if (step === "invalid") {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", padding: spacing.xl, backgroundColor: colors.bg }}>
        <T weight="bold" style={{ fontSize: 22, textAlign: "center" }}>Esta invitación ya no es válida</T>
        <T style={{ marginTop: spacing.md, textAlign: "center", color: colors.muted }}>
          Pide una nueva a quien te la envió.
        </T>
      </View>
    );
  }

  const expiryLabel =
    preview?.membership === "temporary" && preview.expires_at
      ? `Invitación temporal · acceso hasta el ${new Date(preview.expires_at).toLocaleDateString("es-ES")}`
      : "Invitación sin expiración";

  return (
    <ScrollView contentContainerStyle={{ padding: spacing.xl, backgroundColor: colors.bg, flexGrow: 1 }}>
      {step === "welcome" && preview ? (
        <View>
          <T weight="bold" style={{ fontSize: 26 }}>{preview.group_name}</T>
          <T style={{ marginTop: spacing.sm, fontSize: 16 }}>
            {(preview.inviter_name ?? "Alguien") + " te ha invitado"}
          </T>
          <T style={{ marginTop: spacing.sm, color: colors.muted }}>{expiryLabel}</T>
          <T style={{ marginTop: spacing.lg, color: colors.muted }}>
            Los demás verán tu nombre y tu posición cuando la compartas.
          </T>
          {error ? <T style={{ color: colors.danger, marginTop: spacing.md }}>{error}</T> : null}
          <Button
            title={`Unirme al círculo de ${preview.group_name}`}
            onPress={() => setStep("signup")}
            style={{ marginTop: spacing.xl }}
          />
        </View>
      ) : null}

      {step === "signup" ? (
        <View>
          <T weight="bold" style={{ fontSize: 22 }}>Crea tu cuenta</T>
          <TextInput
            placeholder="Email"
            placeholderTextColor={colors.muted}
            autoCapitalize="none"
            keyboardType="email-address"
            value={email}
            onChangeText={setEmail}
            style={{ marginTop: spacing.lg, borderWidth: 1, borderColor: colors.border, borderRadius: 12, padding: spacing.md, color: colors.onSurface }}
          />
          <TextInput
            placeholder="Contraseña"
            placeholderTextColor={colors.muted}
            secureTextEntry
            value={password}
            onChangeText={setPassword}
            style={{ marginTop: spacing.md, borderWidth: 1, borderColor: colors.border, borderRadius: 12, padding: spacing.md, color: colors.onSurface }}
          />
          {error ? <T style={{ color: colors.danger, marginTop: spacing.md }}>{error}</T> : null}
          <Button title="Continuar" onPress={doSignup} disabled={!email.includes("@") || password.length < 6} style={{ marginTop: spacing.xl }} />
        </View>
      ) : null}

      {step === "consents" ? (
        <View>
          <T weight="bold" style={{ fontSize: 22 }}>Consentimientos</T>
          {REQUIRED_DOCS.map((d: { id: string; title: string }) => (
            <Pressable
              key={d.id}
              onPress={() => setAcceptedDocs((p) => ({ ...p, [d.id]: !p[d.id] }))}
              style={{ flexDirection: "row", alignItems: "center", marginTop: spacing.lg }}
            >
              <T style={{ fontSize: 18 }}>{acceptedDocs[d.id] ? "☑" : "☐"}</T>
              <T style={{ marginLeft: spacing.sm, flex: 1 }}>{d.title}</T>
            </Pressable>
          ))}
          {error ? <T style={{ color: colors.danger, marginTop: spacing.md }}>{error}</T> : null}
          <Button
            title="Acepto y continúo"
            onPress={doConsents}
            disabled={!REQUIRED_DOCS.every((d: { id: string }) => acceptedDocs[d.id])}
            style={{ marginTop: spacing.xl }}
          />
        </View>
      ) : null}

      {step === "profile" ? (
        <View>
          <T weight="bold" style={{ fontSize: 22 }}>Tu perfil en el círculo</T>
          <TextInput
            placeholder="Nombre visible"
            placeholderTextColor={colors.muted}
            value={displayName}
            onChangeText={setDisplayName}
            style={{ marginTop: spacing.lg, borderWidth: 1, borderColor: colors.border, borderRadius: 12, padding: spacing.md, color: colors.onSurface }}
          />
          <T weight="semibold" style={{ marginTop: spacing.lg }}>Color de avatar</T>
          <View style={{ flexDirection: "row", gap: spacing.sm, marginTop: spacing.sm }}>
            {AVATAR_COLORS.map((c) => (
              <Pressable
                key={c}
                onPress={() => setAvatarColor(c)}
                style={{
                  width: 40, height: 40, borderRadius: 20, backgroundColor: c,
                  borderWidth: avatarColor === c ? 3 : 0, borderColor: colors.onSurface,
                }}
              />
            ))}
          </View>
          {error ? <T style={{ color: colors.danger, marginTop: spacing.md }}>{error}</T> : null}
          <Button
            title={`Entrar a ${preview?.group_name ?? "mi círculo"}`}
            onPress={doJoin}
            disabled={!displayName.trim()}
            style={{ marginTop: spacing.xl }}
          />
        </View>
      ) : null}
    </ScrollView>
  );
}
