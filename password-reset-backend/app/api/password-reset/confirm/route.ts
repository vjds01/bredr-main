import { NextRequest, NextResponse } from "next/server";

import { adminAuth, adminDb } from "@/lib/firebase-admin";
import { verifyVerificationToken } from "@/lib/security";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const verificationToken = String(body.verificationToken || "").trim();
    const newPassword = String(body.newPassword || "");

    if (newPassword.length < 6) {
      return NextResponse.json(
        { ok: false, message: "Password must be at least 6 characters." },
        { status: 400 },
      );
    }

    const token = verifyVerificationToken(verificationToken);
    const resetRef = adminDb().collection("passwordResetOtps").doc(token.resetId);
    const resetDoc = await resetRef.get();

    if (!resetDoc.exists || resetDoc.data()?.consumed === true) {
      return NextResponse.json(
        {
          ok: false,
          message:
            "This reset code has already been used. Please request a new one.",
        },
        { status: 400 },
      );
    }

    await adminAuth().updateUser(token.uid, { password: newPassword });
    await resetRef.update({
      consumed: true,
      consumedAt: new Date(),
    });

    return NextResponse.json({
      ok: true,
      message: "Your password has been updated.",
    });
  } catch (error) {
    console.error("password-reset/confirm failed", error);
    return NextResponse.json(
      {
        ok: false,
        message:
          "We could not update your password. Please request a new code and try again.",
      },
      { status: 400 },
    );
  }
}
