-- Expense classification for new records. Existing rows remain intact and may
-- have null category/payment_method until an owner chooses to edit them.
alter table public.expenses add column if not exists category text;
alter table public.expenses add column if not exists payment_method text;
alter table public.expenses drop constraint if exists expenses_category_check;
alter table public.expenses add constraint expenses_category_check check (
  category is null or category in (
    'Electricity','Fuel','Education','Health','Grocery','Food','Service',
    'Govt Charges','Material','Travel','Clothing','Connectivity','Spiritual','Styling','Misc.'
  )
);
alter table public.expenses drop constraint if exists expenses_payment_method_check;
alter table public.expenses add constraint expenses_payment_method_check check (
  payment_method is null or payment_method in ('cash','online')
);

create or replace function public.validate_new_expense()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if nullif(trim(new.name),'') is null then raise exception 'Expense name is required'; end if;
  if new.expense_date is null then raise exception 'Expense date is required'; end if;
  if new.amount <= 0 or new.amount <> trunc(new.amount) then raise exception 'Expense amount must be a positive whole rupee amount'; end if;
  if new.payment_method is null or new.payment_method not in ('cash','online') then raise exception 'Choose Cash or Online payment'; end if;
  if new.category is null or new.category not in (
    'Electricity','Fuel','Education','Health','Grocery','Food','Service',
    'Govt Charges','Material','Travel','Clothing','Connectivity','Spiritual','Styling','Misc.'
  ) then raise exception 'Choose a valid expense category'; end if;
  return new;
end;
$$;
drop trigger if exists expenses_validate_new on public.expenses;
create trigger expenses_validate_new before insert on public.expenses
for each row execute function public.validate_new_expense();
notify pgrst, 'reload schema';
