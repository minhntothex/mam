-- ============================================================================
-- Mâm — Scalable currency & amount input format preferences
-- ============================================================================

alter table public.user_settings
  add column if not exists default_currency text not null default 'VND',
  add column if not exists amount_input_format text not null default 'auto';
