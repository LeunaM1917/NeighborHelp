# Claude Code / Claude agent context

This project uses shared agent docs. **Follow [AGENTS.md](./AGENTS.md) and [knowledge.md](./knowledge.md)** for all tasks.

## Quick context

- **NeighborHelp** — Flutter + Firebase marketplace (customers, providers, admin).
- **Mobile parity is mandatory** for customer/provider UI (see `.cursor/rules/customer-provider-mobile-parity.mdc`).
- **Never commit API keys**; see skill `.cursor/skills/neighborhelp-local-secrets/SKILL.md`.

## Skills

- Project: `.cursor/skills/neighborhelp-local-secrets/`, `.cursor/skills/neighborhelp-flutter-firebase/`
- Provider-installed: `.agents/skills/` (Dart + Flutter packs via `npx skills add … --agent cursor`)

When editing Dart/Flutter, prefer guidance from installed **dart-lang** and **flutter** skills before inventing new patterns.
