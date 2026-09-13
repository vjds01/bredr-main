# Breedr clinic verification web app

1. Create an Apps Script project and link it to the same standard Google Cloud project used by Firebase.
2. Copy `Code.gs` and `appsscript.json` into the project.
3. In **Project Settings > Script properties**, add:
   - `FIREBASE_PROJECT_ID`: the Firebase project ID
   - `FIREBASE_WEB_API_KEY`: the Firebase Web API key
   - `TEST_RECIPIENT`: `breedr0123@gmail.com`
4. In Google Cloud IAM, grant the account executing the script permission to update Firestore (for example, Cloud Datastore User). Do not place service-account private keys in the script.
   The manifest explicitly requests both `datastore` and `cloud-platform`
   scopes accepted by the Firestore REST API. After adding or changing these
   scopes, revoke the script's old grant and run `authorizeBreedrServices`
   again so the new access token contains them.
5. Deploy as a web app, execute as yourself, and allow access to anyone with the link. Copy the `/exec` URL.
6. Build Breedr with:

   `flutter build apk --release --dart-define=HEALTH_VERIFICATION_ENDPOINT=YOUR_EXEC_URL`

Opening an email link only displays the review page. A separate confirmed form submission records the clinic decision. Tokens are hashed, expire after seven days, and are cleared after processing.

The mobile client never creates verification-request documents directly. It
sends its Firebase ID token plus the fixed pet and record IDs to this web app.
The script verifies the token, reads the canonical record from Firestore,
checks ownership and consent, and creates the request using server authority.

After changing `Code.gs`, use **Deploy > Manage deployments > Edit**, select
**New version**, and deploy it. Keep the same `/exec` URL so installed APKs do
not need to be rebuilt.
