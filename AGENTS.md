# Agent instructions (NeighborHelp)

Read [knowledge.md](./knowledge.md) first for architecture, stack, and secrets policy.

## Working agreements

1. **One Flutter codebase** for web and mobile — customer/provider changes must keep mobile parity (`.cursor/rules/customer-provider-mobile-parity.mdc`).
2. **No secrets in git** — no `AIza…` keys, service account JSON, or filled `.env` files in commits.
3. **Minimize scope** — match existing patterns in the file you edit; run `flutter analyze` on touched Dart files.
4. **Do not commit** unless the user explicitly asks.

## Project skills (use when relevant)

| Skill | When |
|-------|------|
| `neighborhelp-local-secrets` | API keys, Firebase config, `secrets.local.json`, GitGuardian leaks |
| `neighborhelp-flutter-firebase` | Firestore, Auth, bookings, provider/customer data flows |

## Installed provider skills

Install or refresh with the [Vercel skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add dart-lang/skills --agent cursor -y
npx skills add flutter/agent-plugins --agent cursor -y
```

List what was installed:

```bash
npx skills add dart-lang/skills --agent cursor --list
npx skills add flutter/agent-plugins --agent cursor --list
```

Skills are copied/symlinked for Cursor under **`.agents/skills/`** (project) or **`~/.cursor/skills/`** (with `-g`). Prefer project install so teammates get the same skills.

Recommended for this repo:

- **dart-lang/skills** — Dart language and tooling
- **flutter/agent-plugins** — Flutter UI, testing, and agent workflows

## MCP (optional)

Add Firebase/Supabase/etc. via Cursor **Settings → MCP** or `.cursor/mcp.json` when you need live console access. Not required for day-to-day Flutter edits.

## Key files

- Data: `lib/services/firestore_service.dart`, `lib/constants/collections.dart`
- Auth: `lib/services/auth_service.dart`, `lib/config/google_oauth.dart`
- Theming: `lib/theme/`, `lib/figma_ui/figma_colors.dart`
- Cloud Functions: `functions/index.js`, `functions/.env.example`
