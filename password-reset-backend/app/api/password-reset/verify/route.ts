import { NextRequest, NextResponse } from "next/server";

import { adminDb } from "@/lib/firebase-admin";
import { createVerificationToken, hashOtp } from "@/lib/security";

const maxAttempts = 5;
const verifiedTtlMs = 10 * 60 * 1000;

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const resetId = String(body.resetId || "").trim();
    const code = String(body.code || "").trim();

    if (!resetId || !/^\d{6}$/.test(code)) {
      return NextResponse.json(
        { ok: false, message: "Please enter the 6-digit code." },
        { status: 400 },
      );
    }

    const resetRef = adminDb().collection("passwordResetOtps").doc(resetId);
    const resetDoc = await resetRef.get();

    if (!resetDoc.exists) {
      return NextResponse.json(
        { ok: false, message: "This code is invalid or has expired." },
        { status: 400 },
      );
    }

    const data = resetDoc.data()!;
    const expiresAtMs = data.expiresAt?.toMillis?.() ?? 0;
    const attempts = Number(data.attempts || 0);

    if (data.consumed || Date.now() > expiresAtMs || attempts >= maxAttempts) {
      return NextResponse.json(
        { ok: false, message: "This code is invalid or has expired." },
        { status: 400 },
      );
    }

    if (data.codeHash !== hashOtp(resetId, code)) {
      await resetRef.update({ attempts: attempts + 1 });
      return NextResponse.json(
        { ok: false, message: "That code is incorrect. Please try again." },
        { status: 400 },
      );
    }

    const verificationToken = createVerificationToken({
      resetId,
      email: data.email,
      uid: data.uid,
      expiresAt: Date.now() + verifiedTtlMs,
    });

    await resetRef.update({
      verifiedAt: new Date(),
      attempts,
    });

    return NextResponse.json({
      ok: true,
      email: data.email,
      verificationToken,
    });
  } catch (error) {
    console.error("password-reset/verify failed", error);
    return NextResponse.json(
      {
        ok: false,
        message:
          "We could not verify the code right now. Please try again later.",
      },
      { status: 500 },
    );
  }
}
