# Breedr Password Reset OTP Backend

This is the Vercel backend for Breedr's in-app forgot password OTP flow.

## Vercel environment variables

Add these in Vercel Project Settings > Environment Variables:

```text
BREVO_API_KEY=your Brevo SMTP/API key
BREVO_FROM_EMAIL=your verified Brevo sender email
BREVO_FROM_NAME=Breedr
FIREBASE_PROJECT_ID=breedr-3c5dc
FIREBASE_CLIENT_EMAIL=client_email from Firebase service account JSON
FIREBASE_PRIVATE_KEY=private_key from Firebase service account JSON
FIREBASE_PRIVATE_KEY_BASE64=optional safer Base64 version of the private key
OTP_SECRET=any long random secret string
```

For `FIREBASE_PRIVATE_KEY`, paste the full private key value including:

```text
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

If Vercel stores it on one line, keep the `\n` sequences from the JSON file.

If Vercel has trouble with the multiline key, use `FIREBASE_PRIVATE_KEY_BASE64`
instead. The backend will prefer the Base64 value when both variables exist.

## Endpoints

Request an OTP:

```text
POST /api/password-reset/request
Body: { "email": "user@example.com" }
```

Verify the OTP:

```text
POST /api/password-reset/verify
Body: { "resetId": "...", "code": "123456" }
```

Confirm the new password:

```text
POST /api/password-reset/confirm
Body: { "verificationToken": "...", "newPassword": "newpassword" }
```

## Notes

- OTP codes expire after 10 minutes.
- A code allows up to 5 failed attempts.
- A used reset code cannot be used again.
- Unknown emails return a generic success message so strangers cannot check which emails have Breedr accounts.
