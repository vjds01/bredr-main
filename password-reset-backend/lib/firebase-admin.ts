import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function privateKey(): string {
  const base64Key = process.env.FIREBASE_PRIVATE_KEY_BASE64;
  if (base64Key && base64Key.trim().length > 0) {
    return Buffer.from(base64Key.trim(), "base64").toString("utf8");
  }

  return requiredEnv("FIREBASE_PRIVATE_KEY")
    .replace(/^"|"$/g, "")
    .replace(/\\n/g, "\n");
}

function ensureFirebaseAdmin() {
  if (!getApps().length) {
    initializeApp({
      credential: cert({
        projectId: requiredEnv("FIREBASE_PROJECT_ID"),
        clientEmail: requiredEnv("FIREBASE_CLIENT_EMAIL"),
        privateKey: privateKey(),
      }),
    });
  }
}

export function adminAuth() {
  ensureFirebaseAdmin();
  return getAuth();
}

export function adminDb() {
  ensureFirebaseAdmin();
  return getFirestore();
}
