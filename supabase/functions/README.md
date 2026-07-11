# Edge Functions
Coming in M2–M4 per the Technical Bible §6:
- search-games · game-details · game-deals · browse-deals (proxy/read)
- refresh-deals · evaluate-alerts (scheduled via pg_cron)

Secrets are provided via `supabase secrets set` — never hardcoded.
