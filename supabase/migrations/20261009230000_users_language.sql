-- Add per-user language preference (ID/EN) for the Pacer app.
-- Read/written by LanguageSettingsScreen; falls back to local when null.
alter table public.users
  add column if not exists language text not null default 'id'
  check (language in ('id', 'en'));
