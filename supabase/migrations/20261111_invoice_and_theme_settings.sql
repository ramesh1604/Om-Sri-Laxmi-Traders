alter table public.store_settings
  add column if not exists invoice_note_language text not null default 'en',
  add column if not exists invoice_bank_name text not null default 'Union Bank of India (Mancherial Branch)',
  add column if not exists invoice_bank_account text not null default '03631 40100 00004',
  add column if not exists invoice_bank_ifsc text not null default 'UBIN0803634';

alter table public.store_settings drop constraint if exists store_settings_invoice_note_language_check;
alter table public.store_settings add constraint store_settings_invoice_note_language_check
  check (invoice_note_language in ('en', 'te'));
