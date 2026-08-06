import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function hasEnv(name: string): boolean {
  return Boolean(process.env[name]?.trim());
}

export async function GET() {
  return NextResponse.json({
    ok: true,
    service: "breedr-password-reset",
    timestamp: new Date().toISOString(),
    env: {
      brevoApiKey: hasEnv("BREVO_API_KEY"),
      brevoFromEmail: hasEnv("BREVO_FROM_EMAIL"),
      brevoFromName: hasEnv("BREVO_FROM_NAME"),
      firebaseProjectId: hasEnv("FIREBASE_PROJECT_ID"),
      firebaseClientEmail: hasEnv("FIREBASE_CLIENT_EMAIL"),
      firebasePrivateKey: hasEnv("FIREBASE_PRIVATE_KEY"),
      firebasePrivateKeyBase64: hasEnv("FIREBASE_PRIVATE_KEY_BASE64"),
      otpSecret: hasEnv("OTP_SECRET"),
    },
  });
}
