# HyperHunt Technical Bible

**Version 1.1 — Founding architecture document**
**Status: Ratified**

---

## 0. Purpose and authority of this document

The HyperHunt Constitution defines *what* we build and *why*. This Technical Bible defines *how* we build it. Where the Constitution is the product's soul, this document is its skeleton: the architecture, conventions, and engineering rules that every line of HyperHunt code must respect.

The relationship between the two documents is strict. The Constitution always wins on questions of product scope, vision, and principles. This Bible wins on questions of implementation. If the two ever appear to conflict, the conflict is escalated to the founder and resolved by amending one of the documents — never by a developer quietly picking a side in code.

Like the Constitution, this document is a living source of truth. It changes only through deliberate, recorded amendments (a pull request that modifies this file, reviewed and merged). Code that contradicts this document is a bug, even if it works.

---

## 1. Security foundations (non-negotiable, and first for a reason)

This section comes before architecture because HyperHunt handles user accounts, and because the original constitution draft contained live credentials. Trust is one of our constitutional goals ("Build trust with users"), and trust dies fastest through a security incident.

**Rule 1.1 — Secrets never live in documents, source code, or the Git repository.** No API keys, database passwords, service keys, or tokens may appear in the Constitution, this Bible, README files, commit history, or source files. Founder's note: the credentials in the Constitution draft have had limited exposure, so immediate rotation is deferred at the founder's discretion — but they move into the secrets pipeline (Rule 1.2) during M0, they are removed from the Constitution document itself, and the Supabase secret key and database password are rotated as a mandatory pre-launch checklist item regardless. From this point forward, no new secret is ever written into a document.

**Rule 1.2 — Secrets live in exactly two places.** Local development uses a `.env` file that is listed in `.gitignore` from the very first commit. Deployed backend logic (Supabase Edge Functions) uses Supabase's built-in secrets manager (`supabase secrets set`). CI uses GitHub Actions encrypted secrets. Nothing else.

**Rule 1.3 — The Flutter client is a hostile environment.** Anything shipped inside the app binary can be extracted by a motivated user. Therefore the client may only ever hold *publishable* credentials: the Supabase URL and the Supabase publishable (anon) key, which are designed to be public and are safe only because Row Level Security enforces access. The RAWG key, IsThereAnyDeal key, Supabase secret key, and Knock secret key must never be embedded in the Flutter app. All calls that require those keys are proxied through our backend (Section 4).

**Rule 1.4 — Row Level Security is on for every table, always.** No table is created without an RLS policy. The default posture is deny; policies grant users access to their own rows only. The Supabase secret (service-role) key, which bypasses RLS, is used exclusively inside Edge Functions and never leaves the server.

**Rule 1.5 — Least privilege by default.** Edge Functions get only the secrets they need. Database roles are not widened for convenience. If something seems to require broad access, that's a design smell to escalate, not a permission to grant.

---

## 2. Architecture overview

HyperHunt is a three-layer system: a Flutter client, a Supabase backend, and a set of external data providers that we treat as untrusted, rate-limited, and occasionally wrong.

```
┌──────────────────────────────────────────────┐
│               Flutter App                    │
│  (iOS / Android / Web later)                 │
│  UI · state · local cache · Supabase SDK     │
└──────────────┬───────────────────────────────┘
               │  Supabase publishable key + user JWT
┌──────────────▼───────────────────────────────┐
│               Supabase                       │
│  Auth (accounts, sessions)                   │
│  Postgres (all app data, RLS everywhere)     │
│  Edge Functions (API proxy, alert engine)    │
│  pg_cron (scheduled jobs)                    │
│  Storage (avatars, later)                    │
└───────┬──────────────┬──────────────┬────────┘
        │              │              │   server-held API keys
┌───────▼─────┐ ┌──────▼──────┐ ┌─────▼─────────────┐
│    RAWG     │ │ CheapShark  │ │ IsThereAnyDeal    │
│  metadata   │ │  live deals │ │  price history /  │
│  & catalog  │ │  US stores  │ │  waitlist-style   │
└─────────────┘ └─────────────┘ └───────────────────┘
                     Knock → push notifications
```

The single most important architectural decision: **the Flutter app never calls RAWG or IsThereAnyDeal directly.** Every external API call flows through Supabase Edge Functions. This gives us four things at once: the API keys stay server-side (Rule 1.3), we can cache responses in Postgres to respect rate limits, we can normalize three different APIs' data shapes into one clean internal format, and we can swap or add providers later without shipping an app update. CheapShark happens to be keyless, but it goes through the same proxy for consistency and caching.

The second most important decision: **Postgres is our cache, not just our database.** External game data (metadata, deals, price points) is fetched once, stored with a freshness timestamp, and served from our own tables until stale. The app talks to *our* data model, never to a raw third-party response.

---

## 3. Technology stack (locked for Version 1)

| Layer | Choice | Why |
|---|---|---|
| Client | Flutter (stable channel, Dart 3) | Constitutional mandate; one codebase for iOS + Android |
| State management | Riverpod | Compile-safe, testable, scales from simple to complex without rewrites |
| Navigation | go_router | Declarative, deep-link ready (needed for notification taps) |
| HTTP client | dio | Interceptors for logging/retry; used only against our own Edge Functions |
| Local cache | drift (SQLite) for offline game/wishlist cache; shared_preferences for trivial flags | Fast cold starts, offline browsing of wishlist |
| Backend | Supabase: Auth, Postgres, Edge Functions (Deno/TypeScript), pg_cron | Constitutional mandate; one vendor covers auth + data + serverless |
| Game metadata | RAWG API | The "IMDb of games" — 350k+ titles, genres, screenshots, release dates |
| Live deals | CheapShark API | Free, keyless, solid US-store deal coverage |
| Price history & broader deals | IsThereAnyDeal API | Historical lows, more storefronts, price-cut data |
| Push notifications | Knock | Constitutional choice; handles delivery, preferences, batching |
| Repo & CI | GitHub + GitHub Actions | Constitutional mandate |

New dependencies require a one-paragraph justification in the PR description. "Quality over quantity" applies to packages too — every dependency is a maintenance liability.

---

## 4. The game identity problem (our hardest data problem)

RAWG, CheapShark, and IsThereAnyDeal each have their own game IDs. Nothing in HyperHunt works — not wishlists, not alerts, not "this game you saved is on sale" — unless we can say with confidence that RAWG game 3498, CheapShark gameID 146, and an ITAD entry are all *Grand Theft Auto V*.

Our strategy: maintain a canonical `games` table that we own, and use the **Steam App ID as the primary join key**, because all three providers expose it for the large majority of PC titles. Where a Steam App ID is unavailable (console-only titles, delisted games), we fall back to normalized-title + release-year matching, and we store a `match_confidence` value so low-confidence links can be reviewed rather than silently trusted.

Every game in HyperHunt therefore has one internal UUID, with columns for `rawg_id`, `steam_app_id`, `cheapshark_game_id`, and `itad_id`, any of which may be null. Wishlists, alerts, and deals all reference our internal UUID — never a third-party ID. This is the moat that lets us change providers later without a data migration nightmare.

---

## 5. Data model (Version 1 schema)

The schema below is the starting shape, expressed as intent rather than final DDL; the actual migrations live in `supabase/migrations/` and are the executable truth. Every table gets RLS; policies noted inline.

```
profiles              -- 1:1 with auth.users (Supabase-managed)
  id (uuid, PK, = auth.users.id)
  username, avatar_url, created_at
  RLS: users read any profile, write only their own

user_preferences
  user_id (PK → profiles)
  favorite_genres (text[]), favorite_platforms (text[])
  advanced_tooltips (bool)        -- the Constitution's "show more info" toggle
  RLS: owner only

games                 -- canonical catalog cache (Section 4)
  id (uuid, PK)
  title, slug, release_date, cover_url
  genres (text[]), platforms (text[]), metacritic (int)
  rawg_id, steam_app_id, cheapshark_game_id, itad_id
  match_confidence (real), metadata_refreshed_at (timestamptz)
  RLS: read for all authenticated users; write only via service role

deals                 -- current live deals, refreshed by cron
  id (uuid, PK)
  game_id (→ games), store_id (→ stores)
  price, retail_price, discount_pct, deal_url
  source ('cheapshark' | 'itad'), fetched_at, expires_hint
  RLS: read for all authenticated; write via service role

price_history         -- sparse historical points from ITAD
  game_id, store_id, price, recorded_at
  RLS: read all authenticated; write via service role

stores                -- storefront registry (names, icons) from CheapShark
  RLS: read all; write via service role

wishlist_items
  user_id, game_id, added_at, note
  UNIQUE (user_id, game_id)
  RLS: owner only

alerts
  id, user_id
  kind ('game_price' | 'genre_sale')
  game_id (nullable), genre (nullable)
  price_threshold (numeric, nullable), min_discount_pct (int, nullable)
  active (bool), last_triggered_at
  RLS: owner only

notifications_log     -- what we sent, to prevent duplicate pings
  user_id, alert_id, deal_id, sent_at
  RLS: owner read; write via service role
```

Two schema principles govern all future tables. First, user-owned data always carries a `user_id` column and an owner-only RLS policy — no exceptions, no "we'll add it later." Second, anything sourced from an external API carries a `fetched_at`/`refreshed_at` timestamp so staleness is a queryable fact, not a guess.

## 6. Backend logic: Edge Functions and scheduled jobs

Edge Functions are our entire server-side codebase for Version 1. Each function is small, single-purpose, and named for what it does.

**Proxy/read functions (called by the app):** `search-games` (proxies RAWG search, upserts results into `games`), `game-details` (returns our cached record, refreshing from RAWG if stale beyond 7 days), `game-deals` (returns current deals + price history for one game, refreshing from CheapShark/ITAD if stale beyond ~6 hours), and `browse-deals` (the Deals tab feed, served from our `deals` table).

**Scheduled functions (pg_cron, no app involvement):** `refresh-deals` runs every few hours, pulling front-page deals from CheapShark and price cuts from ITAD, upserting into `deals`. `evaluate-alerts` runs after each refresh: it joins fresh deals against active alerts (price thresholds for wishlisted games, discount thresholds for followed genres), writes to `notifications_log`, and hands matched events to Knock for delivery. Deduplication rule: a given (alert, deal) pair notifies at most once — respecting users' attention is constitutional.

**The freshness contract (budget-optimized until revenue).** Ratified decision: until the app pays for itself, we run in *budget mode* and lean hard on the one provider that costs nothing.

CheapShark is free, keyless, and explicitly public — so it becomes the workhorse for anything price-shaped. The `refresh-deals` cron pulls the deals feed every 6 hours (a courteous cadence for a free service; we identify ourselves with a proper User-Agent), and `game-deals` will do an on-demand CheapShark refresh when a user opens a game whose deal data is older than 6 hours. Live-ish prices where users are actually looking, zero dollars spent.

RAWG is the scarce resource (free tier on the order of 20k requests/month), so it is touched only on cache misses: a game's metadata is fetched once and considered fresh for 30 days, search results are upserted into our `games` table so repeated searches hit Postgres instead of RAWG, and there is no bulk background refresh of metadata in V1 — release dates and cover art simply don't change often enough to justify it.

IsThereAnyDeal is free but rate-limited, so it is lazy-loaded: price history and historical-low data are fetched only when a user opens a game's detail page, then cached for 24 hours (historical lows for 7 days, since they change rarely by definition).

All TTLs live in a `config` table, not in code, so post-launch we tighten freshness by updating one row — no app release, no redeploy. The app always shows "prices updated X ago" on deal surfaces; we never present cached prices as real-time truth. This is the honest version of fast.

**CheapShark endpoint map (from apidocs.cheapshark.com), for the functions above:** `/deals` is the main feed and supports the filters we need for custom deal queries — `storeID`, `upperPrice`/`lowerPrice`, `onSale`, `metacritic`, `steamRating`, `AAA`, `title`, plus `sortBy` (Deal Rating, Savings, Price, Metacritic, Release) and pagination via `pageNumber`/`pageSize` (max 60 per page). `/games?title=` looks a game up by name and `/games?id=` returns its cheapest current price plus cheapest-ever — useful for the "historical low" badge without an ITAD call. `/deals?id=` resolves an individual deal, and `/stores` supplies the store registry with logo/banner/icon URLs that seed our `stores` table. Critically, CheapShark's game objects include `steamAppID`, which reinforces the Section 4 join-key strategy. Genre-based sale alerts are the one thing CheapShark can't do alone (it has no genre data) — the alert engine joins CheapShark deals against RAWG genres already cached in our `games` table, which costs zero additional API calls.

## 7. Flutter application architecture

The app uses a **feature-first structure with three layers per feature**. This mirrors how a real team scales: features are owned end-to-end, and layers keep UI dumb and logic testable.

```
lib/
  core/            -- theme, router, dio client, error types, formatting utils
  features/
    auth/
    home_feed/
    search/
    game_details/
    deals/
    wishlist/
    alerts/
    profile/
      presentation/   -- widgets, screens, controllers (Riverpod)
      domain/         -- entities, use-case logic, pure Dart, zero Flutter imports
      data/           -- repositories, DTOs, Supabase/Edge Function calls, drift cache
  main.dart
```

The dependency rule is one-directional: presentation depends on domain, domain depends on nothing, data implements interfaces that domain defines. A widget never constructs an HTTP call; a repository never imports a widget. Domain entities (e.g., `Game`, `Deal`, `Alert`) are plain Dart classes fully testable without a device.

**State management convention:** every screen gets a Riverpod controller exposing an explicit UI state (`loading / data / error / empty`). The four-state rule is mandatory — the Constitution demands a premium feel, and premium apps never show a blank screen or an unhandled spinner. Empty states are designed, not accidental.

**Design system:** `core/theme/` defines the tokens once — near-black surfaces, lime green as the single primary accent, cyan strictly for secondary/informational accents, generous spacing, one type scale. No screen hard-codes a color or font size. "Every screen answers one question" is enforced in design review: if a screen's one question can't be stated in a sentence, the screen is redesigned.

**Offline posture for V1:** wishlist and previously-viewed game details are cached locally in drift and readable offline; deals require connectivity and say so gracefully. Full offline sync is explicitly out of scope for Version 1.

## 8. Repository layout, Git, and CI

One monorepo: `hyperhunt/`.

```
hyperhunt/
  app/                  -- the Flutter project
  supabase/
    migrations/         -- SQL migrations (the schema's source of truth)
    functions/          -- Edge Functions (TypeScript)
  docs/
    constitution.md     -- the Constitution (secrets removed)
    technical-bible.md  -- this document
    decisions/          -- ADRs: one short file per irreversible decision
  .github/workflows/    -- CI pipelines
```

**Branching:** trunk-based with short-lived feature branches. `main` is always releasable. Every change lands via pull request — including solo work, because the PR description is our engineering log. Commits follow Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`), which later gives us changelogs for free.

**CI (GitHub Actions) on every PR:** `flutter analyze` with zero warnings tolerated, `dart format --set-exit-if-changed`, the full test suite, and a debug build. A PR that fails CI does not merge. Edge Functions get `deno lint` and their own tests.

**Architecture Decision Records:** any decision that would be expensive to reverse (a new dependency, a schema change to a core table, a provider swap) gets a half-page ADR in `docs/decisions/`. Future-us will thank present-us.

## 9. Testing strategy

Testing effort follows risk, not coverage vanity. The **domain layer** (entities, alert-matching logic, price formatting, game-identity matching) is pure Dart and gets thorough unit tests — this is where money-related correctness lives, and a wrong price notification breaks constitutional trust. **Repositories** get unit tests against mocked Edge Function responses, including malformed and empty payloads, because external APIs will lie to us eventually. **Widgets** get tests for the four UI states on each core screen. **Edge Functions** get tests for the alert-evaluation join and the deduplication rule specifically. One end-to-end smoke path (sign up → search → wishlist → see a deal) runs before any release. Target: it should be impossible to break "does the user see the right price" without a test turning red.

## 10. Delivery milestones for Version 1

Each milestone ends in something runnable and reviewed. No milestone begins until the previous one is genuinely done — done means merged, tested, and demo-able, not "mostly works."

**M0 — Foundations.** Repo, CI, Flutter skeleton with theme and navigation shell, Supabase project rebuilt with rotated credentials, secrets pipeline proven end-to-end. *Exit test: a themed empty app builds in CI and connects to Supabase.*

**M1 — Accounts & Profile.** Supabase Auth (email + OAuth), profile creation, preferences (genres/platforms), RLS verified with tests that prove one user cannot read another's rows. *Exit: two test accounts demonstrably isolated.*

**M2 — Catalog: Search & Game Details.** `search-games` and `game-details` functions, canonical `games` table live, search screen and details screen with all four UI states. *Exit: search any of 100 sample titles and get a polished detail page.*

**M3 — Deals & Wishlist.** `refresh-deals` cron, Deals tab, wishlist add/remove with offline cache, deals surfaced on game detail pages with store icons and "updated X ago." *Exit: a wishlisted game visibly shows its live deal.*

**M4 — Alerts & Notifications.** Alert creation UI, `evaluate-alerts` job, Knock integration, notification tap deep-links to the game. Deduplication proven by test. *Exit: drop a price threshold on a real deal and receive exactly one push.*

**M5 — Home Feed.** Personalized feed assembled from preferences + wishlist: new releases in favorite genres, deals on wishlisted games, notable discounts. Rule-based ranking only — no ML in V1. *Exit: two accounts with different preferences see visibly different feeds.*

**M6 — Polish & Release Candidate.** Empty states, animation timing, error copy, performance pass (cold start, list scroll), accessibility pass, store listing assets. *Exit: the founder would show it to a stranger without apologizing.*

## 11. Engineering principles (the culture layer)

The Constitution's product principles translate into engineering behaviors. *Quality over speed* means we don't merge code we wouldn't want to maintain, even at milestone pressure. *Never overwhelm users* means we also never overwhelm the codebase — one way to do a thing, not three. *Respect users' time* means performance is a feature: cold start under two seconds and 60fps scrolling are tracked, not hoped for. *Build trust* means we log errors, not user behavior we don't need; V1 ships with crash reporting and nothing resembling surveillance. And *scalability over shortcuts* means the proxy layer, the canonical game table, and RLS are built correctly in M0–M2 even though cutting them would feel faster — they are precisely the things that cannot be retrofitted cheaply.

## 12. Explicit non-goals for Version 1

To defend the MVP boundary, the following are recorded as deliberate exclusions, mirroring the Constitution: no social features (friends, reviews, community lists), no Steam/Discord sync, no monetization code paths of any kind, no ML-based recommendations (rule-based feed only), no web client, and no offline-first sync engine. Ideas that arise during development are appended to `docs/icebox.md` — captured, honored, and not built.

---

*Amendment history:*
*1.0 — Founding version.*
*1.1 — Ratified budget-mode freshness contract (founder decision): CheapShark as free workhorse with 6h cadence + on-demand refresh, RAWG 30-day metadata TTL with no bulk refresh, ITAD lazy-loaded per detail view; TTLs moved to config table. Added CheapShark endpoint map. Credential rotation deferred to pre-launch checklist per founder; secrets still move to the pipeline in M0.*
