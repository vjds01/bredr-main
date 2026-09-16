# Breedr clinic verification web app

The Apps Script project must be owned and deployed by `breedrteam@gmail.com` so
verification messages are sent by that account. Clinic email addresses are
stored in Script Properties and are not bundled into the mobile APK.

1. While signed in as `breedrteam@gmail.com`, create an Apps Script project and
   link it to the same standard Google Cloud project used by Firebase.
2. Copy `Code.gs` and `appsscript.json` into the project.
3. In **Project Settings > Script properties**, add:
   - `FIREBASE_PROJECT_ID`: the Firebase project ID
   - `FIREBASE_WEB_API_KEY`: the Firebase Web API key
   - `PUBLIC_WEB_APP_URL`: the account-independent deployment URL in the form
     `https://script.google.com/macros/s/DEPLOYMENT_ID/exec` (never include an
     `/u/0`, `/u/1`, or similar account segment)
   - `CLINIC_EMAIL_BREEDR_DEMO`: `breedrteam@gmail.com`
   - `CLINIC_EMAIL_CABUYAO_ANIMAL_CLINIC`: `cabuyaoanimalclinic@gmail.com`
   - `CLINIC_EMAIL_SITIO_BETERINARYO`: `sitiobeterinaryo@gmail.com`
4. In Google Cloud IAM, grant `breedrteam@gmail.com` permission to update
   Firestore (for example, Cloud Datastore User). Do not place service-account
   private keys in the script.
   The manifest explicitly requests both `datastore` and `cloud-platform`
   scopes accepted by the Firestore REST API. After adding or changing these
   scopes, revoke the script's old grant and run `authorizeBreedrServices`
   again so the new access token contains them.
5. Run `authorizeBreedrServices` once in the Apps Script editor and complete the
   authorization prompts while signed in as `breedrteam@gmail.com`.
6. Deploy as a web app, execute as yourself (`breedrteam@gmail.com`), and allow
   access to anyone with the link. Copy the `/exec` URL.
7. Build Breedr with:

   `flutter build apk --release --dart-define=HEALTH_VERIFICATION_ENDPOINT=YOUR_EXEC_URL`

Opening an email link only displays the review page. A separate confirmed form submission records the clinic decision. Tokens are hashed, expire after seven days, and are cleared after processing.

Google does not support multi-login reliably for Apps Script web apps. The
verification email therefore tells clinic reviewers who use multiple Google
accounts to copy the review link into an Incognito/private-browsing window if
Google reports that the page cannot be opened.

The Breedr demo clinic, Cabuyao Animal Clinic, and Sitio Beterinaryo use email
confirmation. Clinics without a configured email remain visible in the app and
their submissions stay available for Veterinary Admin review instead of trying
to send an email.

The mobile client never creates verification-request documents directly. It
sends its Firebase ID token plus the fixed pet and record IDs to this web app.
The script verifies the token, reads the canonical record from Firestore,
checks ownership and consent, and creates the request using server authority.

Each dispatch is attached to the current version of the health record. If the
owner later changes the document, date, veterinarian, clinic, or record type,
older email links are marked as superseded and cannot restore verification.

After changing `Code.gs`, use **Deploy > Manage deployments > Edit**, select
**New version**, and deploy it. Keep the same `/exec` URL so installed APKs do
not need to be rebuilt.
