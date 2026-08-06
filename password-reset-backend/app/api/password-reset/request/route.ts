import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { NextRequest, NextResponse } from "next/server";

import { sendPasswordResetOtp } from "@/lib/brevo";
import { adminAuth, adminDb } from "@/lib/firebase-admin";
import { hashOtp, randomOtp } from "@/lib/security";

const resetTtlMs = 10 * 60 * 1000;

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const email = String(body.email || "").trim().toLowerCase();

    if (!email || !email.includes("@")) {
      return NextResponse.json(
        { ok: false, message: "Please enter a valid email address." },
        { status: 400 },
      );
    }

    let user;
    try {
      user = await adminAuth().getUserByEmail(email);
    } catch {
      return NextResponse.json({
        ok: true,
        message:
          "If this email is connected to a Breedr account, a code has been sent.",
      });
    }

    const resetRef = adminDb().collection("passwordResetOtps").doc();
    const code = randomOtp();
    const expiresAtMs = Date.now() + resetTtlMs;

    await resetRef.set({
      email,
      uid: user.uid,
      codeHash: hashOtp(resetRef.id, code),
      attempts: 0,
      consumed: false,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(expiresAtMs),
    });

    await sendPasswordResetOtp({ email, code });

    return NextResponse.json({
      ok: true,
      resetId: resetRef.id,
      expiresInSeconds: resetTtlMs / 1000,
      message: "A Breedr password reset code has been sent.",
    });
  } catch (error) {
    console.error("password-reset/request failed", error);
    return NextResponse.json(
      {
        ok: false,
        message:
          "We could not send the reset code right now. Please try again later.",
      },
      { status: 500 },
    );
  }
}
