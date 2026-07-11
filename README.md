# HyperHunt

A personalized game discovery and deal-tracking platform. Dark, fast, premium.

- **Constitution** (`docs/constitution.md`) — what we build and why.
- **Technical Bible** (`docs/technical-bible.md`) — how we build it. Read it before writing code.

## Layout
```
app/        Flutter client (feature-first, Riverpod)
supabase/   Migrations (schema source of truth) + Edge Functions
docs/       Constitution, Technical Bible, ADRs, icebox
```

## Getting started
1. `cp .env.example .env` and fill in values (never commit `.env`).
2. `supabase db push` to apply migrations to your project.
3. `cd app && flutter pub get && flutter run --dart-define-from-file=../.env`

## Rules that are always true
- Secrets never appear in code, docs, or commits.
- Every table has RLS. The app holds only publishable keys.
- All external APIs are called via Edge Functions, never the client.
- `main` is always releasable; everything lands via PR with green CI.
