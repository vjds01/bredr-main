import crypto from "crypto";

const tokenVersion = "v1";

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

function secret(): string {
  return requiredEnv("OTP_SECRET");
}

function base64Url(input: string): string {
  return Buffer.from(input).toString("base64url");
}

function fromBase64Url(input: string): string {
  return Buffer.from(input, "base64url").toString("utf8");
}

export function hashOtp(resetId: string, code: string): string {
  return crypto
    .createHmac("sha256", secret())
    .update(`${resetId}:${code}`)
    .digest("hex");
}

export function createVerificationToken(params: {
  resetId: string;
  email: string;
  uid: string;
  expiresAt: number;
}): string {
  const payload = base64Url(
    JSON.stringify({
      v: tokenVersion,
      resetId: params.resetId,
      email: params.email,
      uid: params.uid,
      expiresAt: params.expiresAt,
    }),
  );
  const signature = crypto
    .createHmac("sha256", secret())
    .update(payload)
    .digest("base64url");
  return `${payload}.${signature}`;
}

export function verifyVerificationToken(token: string): {
  resetId: string;
  email: string;
  uid: string;
  expiresAt: number;
} {
  const [payload, signature] = token.split(".");
  if (!payload || !signature) {
    throw new Error("Invalid verification token.");
  }

  const expectedSignature = crypto
    .createHmac("sha256", secret())
    .update(payload)
    .digest("base64url");

  const signatureOk = crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature),
  );

  if (!signatureOk) {
    throw new Error("Invalid verification token.");
  }

  const decoded = JSON.parse(fromBase64Url(payload));
  if (decoded.v !== tokenVersion || Date.now() > decoded.expiresAt) {
    throw new Error("Expired verification token.");
  }

  return {
    resetId: decoded.resetId,
    email: decoded.email,
    uid: decoded.uid,
    expiresAt: decoded.expiresAt,
  };
}

export function randomOtp(): string {
  return crypto.randomInt(100000, 1000000).toString();
}
