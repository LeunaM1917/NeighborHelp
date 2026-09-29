---
name: neighborhelp-local-secrets
description: Manages NeighborHelp Google Maps and Firebase API keys without committing secrets. Use when configuring keys, fixing GitGuardian leaks, editing firebase_options, google-services.json, web maps, Android manifest geo keys, or secrets.local.json.
---

# NeighborHelp local secrets

## Policy

- Never commit `AIza…` strings, service account JSON, or filled `.env` files.
- Keys exposed on GitHub must be **rotated** in Google Cloud; removing from the latest commit is not enough.

## Key mapping

| Secret field | Purpose |
|--------------|---------|
| `FIREBASE_WEB_API_KEY` | Firebase Auth / Firestore on **web** (`lib/firebase_options.dart`) |
| `FIREBASE_ANDROID_API_KEY` | Firebase Android (`google-services.json`) |
| `GOOGLE_MAPS_WEB_API_KEY` | Maps JavaScript API (`web/` loader) |
| `GOOGLE_MAPS_ANDROID_API_KEY` | `com.google.android.geo.API_KEY` in Android manifest |
| `GOOGLE_MAPS_API_KEY` in `functions/.env` | Server Distance Matrix (Cloud Functions only) |

Firebase **Browser** and **Maps Web** keys are usually different. Do not reuse one key for both unless GCP restrictions explicitly allow all required APIs.

## Local workflow

1. Copy `secrets.example.json` → `secrets.local.json` (gitignored).
2. Fill all four client key fields.
3. Run `powershell -ExecutionPolicy Bypass -File scripts/sync-secrets.ps1` when that script exists.
4. Run/build Flutter with `--dart-define-from-file=secrets.local.json`.

## GCP restrictions (after any leak)

- Browser key: HTTP referrers (localhost, Firebase hosting domains, production domain).
- Android Firebase / Maps: app restriction `com.neighborhelp.app` + SHA-1 fingerprints.
- API restrictions: only APIs each key needs (Auth, Firestore, Maps JS, Maps SDK, etc.).

## Check before finishing

- [ ] `rg 'AIza'` on tracked files returns no matches
- [ ] `secrets.local.json` and `functions/.env` are gitignored or untracked
- [ ] User reminded to rotate keys if they were ever public
