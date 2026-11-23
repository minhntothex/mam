-- ============================================================================
-- Mâm — Explicit table privileges for Supabase `authenticated` role
-- Row Level Security policies enforce `auth.uid() = user_id` on every row.
-- ============================================================================

grant usage on schema public to authenticated;

grant select, insert, update, delete on table public.bank_accounts to authenticated;
grant select, insert, update, delete on table public.friend_groups to authenticated;
grant select, insert, update, delete on table public.user_settings to authenticated;
grant select, insert, update, delete on table public.bills to authenticated;

revoke all on table public.bank_accounts from anon;
revoke all on table public.friend_groups from anon;
revoke all on table public.user_settings from anon;
revoke all on table public.bills from anon;
