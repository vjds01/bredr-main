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
    } catch (error) {
      const firebaseError = error as { code?: string; message?: string };
      if (
        firebaseError.code === "auth/user-not-found" ||
        firebaseError.code === "auth/invalid-email"
      ) {
        return NextResponse.json({
          ok: true,
          message:
            "If this email is connected to a Breedr account, a code has been sent.",
        });
      }

      console.error("Firebase user lookup failed", error);
      return NextResponse.json({
          ok: false,
          message:
            "The password reset service is not connected to Firebase correctly yet.",
        },
        { status: 500 },
      );
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
