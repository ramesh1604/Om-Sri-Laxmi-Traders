-- Store GSTIN and address for registered billing customers.
alter table public.customers add column if not exists gstin text;
alter table public.customers add column if not exists address text;
notify pgrst, 'reload schema';
