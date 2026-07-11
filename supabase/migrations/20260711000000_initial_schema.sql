-- ============================================================
-- HyperHunt — Initial Schema
-- Migration 0001 · Technical Bible §5
-- Every table has RLS. Default posture: deny.
-- External-sourced data carries a freshness timestamp.
-- ============================================================

-- ---------- extensions ----------
create extension if not exists pg_cron with schema extensions;

-- ---------- helper: updated_at trigger ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ============================================================
-- config — runtime-tunable values (Bible §6: TTLs live in data,
-- not code, so budget mode can be tightened post-launch with an
-- UPDATE instead of a redeploy)
-- ============================================================
create table public.config (
  key         text primary key,
  value       text not null,
  description text,
  updated_at  timestamptz not null default now()
);
alter table public.config enable row level security;
create policy "config readable by authenticated"
  on public.config for select to authenticated using (true);
-- writes: service role only (bypasses RLS)

insert into public.config (key, value, description) values
  ('ttl_game_metadata_hours',   '720', 'RAWG metadata freshness window (30 days, budget mode)'),
  ('ttl_deals_hours',           '6',   'CheapShark deal freshness window'),
  ('ttl_price_history_hours',   '24',  'ITAD price history freshness window'),
  ('ttl_historical_low_hours',  '168', 'Historical-low freshness window (7 days)'),
  ('deals_cron_interval_hours', '6',   'refresh-deals job cadence');

create trigger config_updated_at before update on public.config
  for each row execute function public.set_updated_at();

-- ============================================================
-- profiles — 1:1 with auth.users, auto-created on signup
-- ============================================================
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  username   text unique check (char_length(username) between 3 and 24),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "profiles readable by authenticated"
  on public.profiles for select to authenticated using (true);
create policy "users update own profile"
  on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- auto-create a profile row when a user signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id);
  insert into public.user_preferences (user_id) values (new.id);
  return new;
end $$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- user_preferences — genres/platforms + UI toggles
-- ============================================================
create table public.user_preferences (
  user_id            uuid primary key references public.profiles (id) on delete cascade,
  favorite_genres    text[] not null default '{}',
  favorite_platforms text[] not null default '{}',
  advanced_tooltips  boolean not null default false,   -- Constitution: "show additional information" toggle
  updated_at         timestamptz not null default now()
);
alter table public.user_preferences enable row level security;
create policy "owner full access to preferences"
  on public.user_preferences for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create trigger user_preferences_updated_at before update on public.user_preferences
  for each row execute function public.set_updated_at();

-- ============================================================
-- games — canonical catalog (Bible §4: our UUID is the identity;
-- steam_app_id is the cross-provider join key)
-- ============================================================
create table public.games (
  id                    uuid primary key default gen_random_uuid(),
  title                 text not null,
  slug                  text not null,
  release_date          date,
  cover_url             text,
  genres                text[] not null default '{}',
  platforms             text[] not null default '{}',
  metacritic            int check (metacritic between 0 and 100),
  rawg_id               bigint unique,
  steam_app_id          bigint,
  cheapshark_game_id    bigint,
  itad_id               text,
  match_confidence      real not null default 1.0 check (match_confidence between 0 and 1),
  metadata_refreshed_at timestamptz not null default now(),
  created_at            timestamptz not null default now()
);
create index games_steam_app_id_idx on public.games (steam_app_id) where steam_app_id is not null;
create index games_cheapshark_idx   on public.games (cheapshark_game_id) where cheapshark_game_id is not null;
create index games_slug_idx         on public.games (slug);
create index games_genres_idx       on public.games using gin (genres);

alter table public.games enable row level security;
create policy "games readable by authenticated"
  on public.games for select to authenticated using (true);
-- writes: service role only (Edge Functions)

-- ============================================================
-- stores — storefront registry seeded from CheapShark /stores
-- ============================================================
create table public.stores (
  id                 uuid primary key default gen_random_uuid(),
  cheapshark_store_id int unique not null,
  name               text not null,
  is_active          boolean not null default true,
  logo_url           text,
  banner_url         text,
  icon_url           text,
  fetched_at         timestamptz not null default now()
);
alter table public.stores enable row level security;
create policy "stores readable by authenticated"
  on public.stores for select to authenticated using (true);

-- ============================================================
-- deals — current live deals, refreshed by cron + on-demand
-- ============================================================
create table public.deals (
  id                 uuid primary key default gen_random_uuid(),
  game_id            uuid not null references public.games (id) on delete cascade,
  store_id           uuid not null references public.stores (id),
  cheapshark_deal_id text unique,
  price              numeric(10,2) not null check (price >= 0),
  retail_price       numeric(10,2) not null check (retail_price >= 0),
  discount_pct       int not null check (discount_pct between 0 and 100),
  deal_url           text not null,
  source             text not null check (source in ('cheapshark','itad')),
  fetched_at         timestamptz not null default now(),
  expires_hint       timestamptz
);
create index deals_game_idx     on public.deals (game_id);
create index deals_discount_idx on public.deals (discount_pct desc);
create index deals_fetched_idx  on public.deals (fetched_at);

alter table public.deals enable row level security;
create policy "deals readable by authenticated"
  on public.deals for select to authenticated using (true);

-- ============================================================
-- price_history — sparse points from ITAD (lazy-loaded, Bible §6)
-- ============================================================
create table public.price_history (
  id          uuid primary key default gen_random_uuid(),
  game_id     uuid not null references public.games (id) on delete cascade,
  store_id    uuid references public.stores (id),
  price       numeric(10,2) not null check (price >= 0),
  recorded_at timestamptz not null,
  fetched_at  timestamptz not null default now(),
  unique (game_id, store_id, recorded_at)
);
create index price_history_game_idx on public.price_history (game_id, recorded_at);

alter table public.price_history enable row level security;
create policy "price history readable by authenticated"
  on public.price_history for select to authenticated using (true);

-- ============================================================
-- wishlist_items — owner-only
-- ============================================================
create table public.wishlist_items (
  id       uuid primary key default gen_random_uuid(),
  user_id  uuid not null references public.profiles (id) on delete cascade,
  game_id  uuid not null references public.games (id) on delete cascade,
  note     text check (char_length(note) <= 500),
  added_at timestamptz not null default now(),
  unique (user_id, game_id)
);
create index wishlist_user_idx on public.wishlist_items (user_id);
create index wishlist_game_idx on public.wishlist_items (game_id);

alter table public.wishlist_items enable row level security;
create policy "owner full access to wishlist"
  on public.wishlist_items for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- alerts — game price thresholds & genre sale alerts
-- ============================================================
create table public.alerts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles (id) on delete cascade,
  kind              text not null check (kind in ('game_price','genre_sale')),
  game_id           uuid references public.games (id) on delete cascade,
  genre             text,
  price_threshold   numeric(10,2) check (price_threshold > 0),
  min_discount_pct  int check (min_discount_pct between 1 and 100),
  active            boolean not null default true,
  created_at        timestamptz not null default now(),
  last_triggered_at timestamptz,
  -- shape rules: a game_price alert targets a game with a price;
  -- a genre_sale alert targets a genre with a discount floor
  constraint alert_shape check (
    (kind = 'game_price' and game_id is not null and price_threshold is not null and genre is null)
    or
    (kind = 'genre_sale' and genre is not null and min_discount_pct is not null and game_id is null)
  )
);
create index alerts_active_idx on public.alerts (active) where active;
create index alerts_user_idx   on public.alerts (user_id);

alter table public.alerts enable row level security;
create policy "owner full access to alerts"
  on public.alerts for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- notifications_log — dedup ledger (Bible §6: one ping per
-- alert/deal pair, ever)
-- ============================================================
create table public.notifications_log (
  id      uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  alert_id uuid not null references public.alerts (id) on delete cascade,
  deal_id  uuid references public.deals (id) on delete set null,
  sent_at  timestamptz not null default now(),
  unique (alert_id, deal_id)
);
create index notifications_user_idx on public.notifications_log (user_id, sent_at desc);

alter table public.notifications_log enable row level security;
create policy "owner reads own notification log"
  on public.notifications_log for select to authenticated
  using (auth.uid() = user_id);
-- writes: service role only (evaluate-alerts job)
