function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim().length === 0) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

export async function sendPasswordResetOtp(params: {
  email: string;
  code: string;
}) {
  const fromEmail = requiredEnv("BREVO_FROM_EMAIL");
  const fromName = process.env.BREVO_FROM_NAME || "Breedr";

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      accept: "application/json",
      "api-key": requiredEnv("BREVO_API_KEY"),
      "content-type": "application/json",
    },
    body: JSON.stringify({
      sender: { email: fromEmail, name: fromName },
      to: [{ email: params.email }],
      subject: "Your Breedr password reset code",
      htmlContent: `
        <div style="font-family:Arial,sans-serif;color:#222;line-height:1.5">
          <h2 style="color:#ff4f67">Breedr password reset</h2>
          <p>Use this verification code to reset your Breedr password:</p>
          <p style="font-size:32px;font-weight:700;letter-spacing:8px;color:#ff4f67">
            ${params.code}
          </p>
          <p>This code expires in 10 minutes.</p>
          <p>If you did not request this, you can safely ignore this email.</p>
        </div>
      `,
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Brevo email failed: ${response.status} ${errorBody}`);
  }
}
