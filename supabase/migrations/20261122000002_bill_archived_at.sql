-- ============================================================================
-- Mâm — Add bill archiving support (`archived_at`)
-- ============================================================================

alter table public.bills
  add column if not exists archived_at timestamptz;

create index if not exists idx_bills_user_archived_updated
  on public.bills (user_id, archived_at, updated_at desc)
  where deleted_at is null;
