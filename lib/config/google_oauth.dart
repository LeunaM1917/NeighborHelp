/// OAuth 2.0 **Web client ID** (ends with `.apps.googleusercontent.com`).
///
/// **Where to find it:** Firebase Console → **Authentication** → **Sign-in method** →
/// **Google** → *Web SDK configuration* → **Web client ID**.
///
/// **Why it’s needed:**
/// - **Android / iOS:** pass this as `serverClientId` on `GoogleSignIn` so Google returns an
///   **ID token** Firebase Auth can use (`signInWithCredential`).
/// - **Web:** pass the same value as `clientId` on `GoogleSignIn`.
///
/// Also ensure **SHA-1** (debug + release) is added under **Project settings** → **Your apps**
/// → Android app, or Google Sign-In on Android will fail after account pick.
///
/// **Web — Error 400 / `origin_mismatch`:** The app uses **Firebase `signInWithPopup`** for
/// Google on web (see [AuthService.signInWithGoogle]), so sign-in goes through Firebase’s
/// auth domain, not raw GIS localhost origins. Ensure Firebase → **Authentication** → **Settings**
/// → **Authorized domains** includes `localhost`. (The **Web client** JS origins in Google Cloud
/// still matter for Android and for any direct GIS / Maps use.)
///
/// **403 / People API / `SERVICE_DISABLED`:** Enable **Google People API** for the same GCP
/// project: Google Cloud Console → **APIs & Services** → **Library** → search **People API** →
/// **Enable**. Sign-in uses it for profile fields (name, photo, email) in some flows.
const String kGoogleWebOAuthClientId = '181576858549-rckc1842eo9540g76881ftpff865sha5.apps.googleusercontent.com';

bool get isGoogleOAuthConfigured => kGoogleWebOAuthClientId.trim().isNotEmpty;
