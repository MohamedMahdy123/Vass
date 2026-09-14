# Vess backend (Supabase)

Postgres schema, Row Level Security, storage, and the two AI-proxy Edge
Functions. The Anthropic API key lives **only** here as a function secret — it
is never shipped in the app.

## One-time setup

```bash
# 1. Install the CLI and sign in
npm i -g supabase
supabase login

# 2. Link this folder to your project (get the ref from the dashboard URL)
supabase link --project-ref <your-project-ref>

# 3. Apply the schema (creates tables, RLS, the 'wardrobe' bucket, triggers)
supabase db push

# 4. Give the Edge Functions the Anthropic key (server-side only)
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

# 5. Deploy the functions
supabase functions deploy analyze-item
supabase functions deploy recommend
```

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are injected into deployed functions
automatically — no need to set them by hand.

## Running the app against it

Pass the project URL and anon key at run time (never commit them):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

With no `--dart-define`, the app runs in **demo mode** (the in-memory prototype)
so it's always launchable.

## Layout

```
supabase/
  migrations/0001_init.sql      schema + RLS + storage + new-user trigger
  functions/
    _shared/cors.ts
    analyze-item/index.ts       photo → attributes   (Claude Haiku 4.5)
    recommend/index.ts          wardrobe → outfit+why (Claude Sonnet 5)
```

## Notes

- **Auth model:** RLS is the security boundary. Every table policy restricts
  rows to `auth.uid()`; the functions verify the caller's JWT before spending on
  a model call.
- **Quotas (M4):** `usage_events` is in place; the `TODO(M4)` markers in each
  function are where free-tier limits get enforced.
- **Pin the SDK:** the functions import `npm:@anthropic-ai/sdk` unpinned for now
  — pin a specific version before production.
