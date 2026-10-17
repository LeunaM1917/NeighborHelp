# NeighborHelp — project knowledge

Community service marketplace: customers browse and book local providers; providers manage services, jobs, and availability. Single **Flutter** app (web + Android/iOS) backed by **Firebase** (Auth, Firestore, Storage, Functions, Messaging).

## Stack

| Layer | Technology |
|-------|------------|
| Client | Flutter 3.x, `google_maps_flutter`, `google_sign_in`, Figma-aligned UI under `lib/figma_ui/` |
| Backend | Firestore, Cloud Functions (`functions/`), Firebase Storage |
| ML (optional) | Sentiment API (`sentiment_api/`, Python) + LSTM artifacts in `LSTM_train/` |
| Firebase project | `neighborhelp-63771` |

## Repo layout (high signal)

- `lib/screens/customer/` — customer shell, browse, bookings, messages
- `lib/screens/provider/` — provider dashboard, jobs, services, profile completion
- `lib/screens/admin/` — admin console
- `lib/screens/auth/` — login, register, `MobileAuthGate`, role selection
- `lib/services/firestore_service.dart` — primary data access
- `lib/services/auth_service.dart` — Firebase Auth + Google Sign-In
- `functions/index.js` — Didit verification, Distance Matrix (Maps server key in `functions/.env`)
- `.cursor/rules/` — Cursor rules (e.g. customer/provider mobile parity)
- `.cursor/skills/` — project-specific agent skills

## Roles and routing

- `UserRole`: customer, provider, admin (see `lib/models/` and `lib/screens/root/root_gate.dart`)
- Native mobile: bottom nav via `lib/figma_ui/app_shell_layout.dart`; web: marketing shell where applicable

## Secrets and API keys

**Never commit** Google/Firebase API keys or `.env` files with real values.

| Key purpose | Where it lives locally |
|-------------|-------------------------|
| Firebase Web (Browser) | `secrets.local.json` → `FIREBASE_WEB_API_KEY` |
| Firebase Android | `secrets.local.json` → `FIREBASE_ANDROID_API_KEY` |
| Maps Web | `secrets.local.json` → `GOOGLE_MAPS_WEB_API_KEY` |
| Maps Android | `secrets.local.json` → `GOOGLE_MAPS_ANDROID_API_KEY` |
| Cloud Functions Maps | `functions/.env` → `GOOGLE_MAPS_API_KEY` |

Use skill **neighborhelp-local-secrets** and rule: rotate any key that was ever pushed to a public GitHub repo.

## Common commands

```bash
flutter pub get
flutter analyze
flutter run --dart-define-from-file=secrets.local.json   # when secrets pipeline is configured
firebase deploy --only functions
powershell -ExecutionPolicy Bypass -File scripts/run-sentiment-api.ps1
```

## Agent skills in this repo

### Custom (authored for NeighborHelp)

- `.cursor/skills/neighborhelp-local-secrets/` — Google/Firebase key hygiene
- `.cursor/skills/neighborhelp-flutter-firebase/` — Firestore + Flutter conventions

### Installed from providers (via `npx skills add`)

See [AGENTS.md](./AGENTS.md) for install commands and paths (`.agents/skills/` or `.cursor/skills/` per CLI).

## Testing

- Unit/widget tests under `test/`
- After customer/provider UI changes: verify **wide web** and **compact/native** layouts (see mobile parity rule)
