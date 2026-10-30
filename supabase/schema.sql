-- Run this once in the Supabase SQL Editor for the store project.
create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null, unit text not null default 'unit', stock_quantity numeric(14,3) not null default 0 check (stock_quantity >= 0),
  mrp numeric(14,2) not null default 0, purchase_rate numeric(14,2) not null default 0, rate_discount_percent numeric(8,3) not null default 0, dealer_discount_percent numeric(8,3) not null default 0,
  last_purchase_date date,
  retail_price numeric(14,2) not null default 0 check (retail_price >= 0), wholesale_price numeric(14,2) not null default 0 check (wholesale_price >= 0), cost_price numeric(14,2) not null default 0 check (cost_price >= 0),
  low_stock_threshold numeric(14,3) not null default 5 check (low_stock_threshold >= 0), created_at timestamptz not null default now()
);
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null, phone text, email text, balance numeric(14,2) not null default 0, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  reference text not null, type text not null check(type in ('sale','payment','stock_adjustment','opening_balance','purchase')), sale_type text check(sale_type in ('retail','wholesale')),
  customer_id uuid references public.customers(id) on delete set null, customer_name text, subtotal numeric(14,2) not null default 0,
  tax numeric(14,2) not null default 0, total numeric(14,2) not null default 0, amount_paid numeric(14,2) not null default 0,
  vendor_name text, invoice_number text, invoice_date date, discount_rate numeric(8,3) not null default 0, discount_amount numeric(14,2) not null default 0,
  net_value numeric(14,2) not null default 0, gst_label text, gst_rate numeric(8,3) not null default 0, round_off numeric(14,2) not null default 0,
  discount_verified boolean not null default false, net_value_verified boolean not null default false, gst_verified boolean not null default false, total_verified boolean not null default false,
  notes text, extra_discount_rate numeric(8,3) not null default 0, payment_days integer not null default 0,
  discount_due_date date, early_payment_discount numeric(14,2) not null default 0, print_discount_rate boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.products add column if not exists cost_price numeric(14,2) not null default 0;
alter table public.products add column if not exists mrp numeric(14,2) not null default 0;
alter table public.products add column if not exists purchase_rate numeric(14,2) not null default 0;
alter table public.products add column if not exists rate_discount_percent numeric(8,3) not null default 0;
alter table public.products add column if not exists dealer_discount_percent numeric(8,3) not null default 0;
alter table public.products add column if not exists last_purchase_date date;
alter table public.products drop column if exists sku cascade;
alter table public.transactions add column if not exists vendor_name text;
alter table public.transactions add column if not exists invoice_number text;
alter table public.transactions add column if not exists invoice_date date;
alter table public.transactions add column if not exists discount_rate numeric(8,3) not null default 0;
alter table public.transactions add column if not exists discount_amount numeric(14,2) not null default 0;
alter table public.transactions add column if not exists net_value numeric(14,2) not null default 0;
alter table public.transactions add column if not exists gst_label text;
alter table public.transactions add column if not exists gst_rate numeric(8,3) not null default 0;
alter table public.transactions add column if not exists round_off numeric(14,2) not null default 0;
alter table public.transactions add column if not exists discount_verified boolean not null default false;
alter table public.transactions add column if not exists net_value_verified boolean not null default false;
alter table public.transactions add column if not exists gst_verified boolean not null default false;
alter table public.transactions add column if not exists total_verified boolean not null default false;
alter table public.transactions add column if not exists extra_discount_rate numeric(8,3) not null default 0;
alter table public.transactions add column if not exists payment_days integer not null default 0;
alter table public.transactions add column if not exists discount_due_date date;
alter table public.transactions add column if not exists early_payment_discount numeric(14,2) not null default 0;
alter table public.transactions add column if not exists print_discount_rate boolean not null default true;
alter table public.transactions drop constraint if exists transactions_type_check;
alter table public.transactions add constraint transactions_type_check check(type in ('sale','payment','stock_adjustment','opening_balance','purchase'));
create table if not exists public.transaction_items (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  transaction_id uuid not null references public.transactions(id) on delete cascade, product_id uuid references public.products(id) on delete set null,
  product_name text not null, quantity numeric(14,3) not null, unit_price numeric(14,2) not null, line_total numeric(14,2) not null,
  hsn text, case_count numeric(14,3) not null default 0, pairs_per_case numeric(14,3) not null default 0, mrp numeric(14,2) not null default 0,
  unit text, discount_amount numeric(14,2) not null default 0, net_value numeric(14,2) not null default 0,
  gst_amount numeric(14,2) not null default 0, item_total numeric(14,2) not null default 0,
  calculated_amount numeric(14,2) not null default 0, amount_verified boolean not null default false, rate_discount_percent numeric(8,3) not null default 0, cost_price numeric(14,2) not null default 0, dealer_discount_percent numeric(8,3) not null default 0,
  sale_discount_rate numeric(8,3) not null default 0, inventory_ref uuid
);
alter table public.transaction_items add column if not exists sale_discount_rate numeric(8,3) not null default 0;
alter table public.transaction_items add column if not exists inventory_ref uuid;
update public.transaction_items ti set sale_discount_rate=tx.discount_rate
from public.transactions tx where tx.id=ti.transaction_id and tx.type='sale' and tx.sale_type='wholesale' and ti.sale_discount_rate=0 and tx.discount_rate<>0;
alter table public.transaction_items add column if not exists hsn text;
alter table public.transaction_items add column if not exists case_count numeric(14,3) not null default 0;
alter table public.transaction_items add column if not exists pairs_per_case numeric(14,3) not null default 0;
alter table public.transaction_items add column if not exists mrp numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists unit text;
alter table public.transaction_items add column if not exists discount_amount numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists net_value numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists gst_amount numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists item_total numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists calculated_amount numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists amount_verified boolean not null default false;
alter table public.transaction_items add column if not exists rate_discount_percent numeric(8,3) not null default 0;
alter table public.transaction_items add column if not exists cost_price numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists dealer_discount_percent numeric(8,3) not null default 0;
-- Recalculate previously saved purchase costs using 5% discount followed by 5% GST.
update public.transaction_items ti set
  cost_price=round(ti.unit_price*0.95*1.05,2),
  dealer_discount_percent=case when ti.mrp>0 then round((1-(ti.unit_price*0.95*1.05)/ti.mrp)*100,3) else 0 end
from public.transactions tx where tx.id=ti.transaction_id and tx.type='purchase';
update public.products p set
  cost_price=latest.cost_price, mrp=latest.mrp, purchase_rate=latest.unit_price,last_purchase_date=latest.purchase_date,
  rate_discount_percent=case when latest.mrp>0 then round((1-latest.unit_price/latest.mrp)*100,3) else 0 end,
  dealer_discount_percent=case when latest.mrp>0 then round((1-latest.cost_price/latest.mrp)*100,3) else 0 end
from (
  select distinct on (ti.product_id) ti.product_id,ti.unit_price,ti.mrp,ti.cost_price,coalesce(tx.invoice_date,tx.created_at::date) as purchase_date
  from public.transaction_items ti join public.transactions tx on tx.id=ti.transaction_id
  where tx.type='purchase' and ti.product_id is not null
  order by ti.product_id,tx.created_at desc,tx.id desc,ti.id desc
) latest where latest.product_id=p.id;
-- Do not keep empty products in the active inventory catalogue.
delete from public.products where stock_quantity=0;
create table if not exists public.store_settings (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  currency text not null default 'INR', tax_rate numeric(6,3) not null default 0 check(tax_rate >= 0 and tax_rate <= 100), unique(owner_id)
);
create table if not exists public.ai_model_profiles (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null, endpoint text not null, model text not null, api_key text not null,
  auth_header_name text not null default 'Authorization', auth_prefix text not null default 'Bearer',
  api_format text not null default 'auto' check(api_format in ('auto','chat_completions','responses','anthropic_messages','gemini_generate_content')),
  auth_mode text not null default 'auto' check(auth_mode in ('auto','bearer','x_api_key','google_api_key','custom','none')),
  extra_headers jsonb not null default '{}'::jsonb check(jsonb_typeof(extra_headers)='object'),
  is_active boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index if not exists ai_model_profiles_one_active_per_owner on public.ai_model_profiles(owner_id) where is_active;
alter table public.ai_model_profiles add column if not exists auth_header_name text not null default 'Authorization';
alter table public.ai_model_profiles add column if not exists auth_prefix text not null default 'Bearer';
alter table public.ai_model_profiles add column if not exists api_format text not null default 'auto';
alter table public.ai_model_profiles add column if not exists auth_mode text not null default 'auto';
alter table public.ai_model_profiles add column if not exists extra_headers jsonb not null default '{}'::jsonb;
alter table public.ai_model_profiles drop constraint if exists ai_model_profiles_api_format_check;
alter table public.ai_model_profiles add constraint ai_model_profiles_api_format_check check(api_format in ('auto','chat_completions','responses','anthropic_messages','gemini_generate_content'));
alter table public.ai_model_profiles drop constraint if exists ai_model_profiles_auth_mode_check;
alter table public.ai_model_profiles add constraint ai_model_profiles_auth_mode_check check(auth_mode in ('auto','bearer','x_api_key','google_api_key','custom','none'));
alter table public.ai_model_profiles drop constraint if exists ai_model_profiles_extra_headers_check;
alter table public.ai_model_profiles add constraint ai_model_profiles_extra_headers_check check(jsonb_typeof(extra_headers)='object');

alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_items enable row level security;
alter table public.store_settings enable row level security;
alter table public.ai_model_profiles enable row level security;
drop policy if exists products_owner on public.products;
create policy products_owner on public.products for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy if exists customers_owner on public.customers;
create policy customers_owner on public.customers for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy if exists transactions_owner on public.transactions;
create policy transactions_owner on public.transactions for select to authenticated using(owner_id=auth.uid());
drop policy if exists transaction_items_owner on public.transaction_items;
create policy transaction_items_owner on public.transaction_items for select to authenticated using(owner_id=auth.uid());
drop policy if exists settings_owner on public.store_settings;
create policy settings_owner on public.store_settings for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy if exists ai_model_profiles_owner on public.ai_model_profiles;
create policy ai_model_profiles_owner on public.ai_model_profiles for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
revoke all on table public.ai_model_profiles from anon, public;
grant select, insert, update, delete on table public.ai_model_profiles to authenticated;

create or replace function public.activate_ai_model(p_id uuid)
returns public.ai_model_profiles language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid:=auth.uid(); v_profile public.ai_model_profiles;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  update ai_model_profiles set is_active=false,updated_at=now() where owner_id=v_owner and is_active;
  update ai_model_profiles set is_active=true,updated_at=now() where id=p_id and owner_id=v_owner returning * into v_profile;
  if not found then raise exception 'AI model profile not found'; end if;
  return v_profile;
end $$;

create or replace function public.complete_sale(p_sale_type text, p_customer_id uuid, p_items jsonb, p_tax_rate numeric default 0, p_amount_paid numeric default 0, p_notes text default null)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid := auth.uid(); v_tx public.transactions; v_subtotal numeric(14,2):=0; v_tax numeric(14,2); v_total numeric(14,2); v_item jsonb; v_product public.products; v_qty numeric(14,3); v_price numeric(14,2);
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_sale_type not in ('retail','wholesale') then raise exception 'Invalid billing type'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then raise exception 'Add at least one item'; end if;
  if p_tax_rate < 0 or p_tax_rate > 100 then raise exception 'Invalid tax rate'; end if;
  if p_customer_id is not null and not exists(select 1 from customers where id=p_customer_id and owner_id=v_owner) then raise exception 'Customer not found'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    if v_qty <= 0 then raise exception 'Quantity must be positive'; end if;
    select * into v_product from products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
    if not found then raise exception 'Product not found'; end if;
    if v_product.stock_quantity < v_qty then raise exception 'Not enough stock for %', v_product.name; end if;
    v_price := case when p_sale_type='wholesale' then v_product.wholesale_price else v_product.retail_price end;
    v_subtotal := v_subtotal + round(v_price*v_qty,2);
  end loop;
  v_tax := round(v_subtotal*p_tax_rate/100,2); v_total := v_subtotal+v_tax;
  if p_amount_paid < 0 or p_amount_paid > v_total then raise exception 'Payment must be between zero and the bill total'; end if;
  if p_customer_id is null and p_amount_paid <> v_total then raise exception 'Select a customer to record an unpaid balance'; end if;
  insert into transactions(owner_id,reference,type,sale_type,customer_id,customer_name,subtotal,tax,total,amount_paid,notes)
  select v_owner, 'BILL-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)), 'sale', p_sale_type, p_customer_id,
    (select name from customers where id=p_customer_id), v_subtotal, v_tax, v_total, p_amount_paid, p_notes returning * into v_tx;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::numeric;
    select * into v_product from products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
    v_price := case when p_sale_type='wholesale' then v_product.wholesale_price else v_product.retail_price end;
    update products set stock_quantity=stock_quantity-v_qty where id=v_product.id and owner_id=v_owner;
    insert into transaction_items(owner_id,transaction_id,product_id,product_name,quantity,unit_price,line_total)
      values(v_owner,v_tx.id,v_product.id,v_product.name,v_qty,v_price,round(v_qty*v_price,2));
  end loop;
  delete from products p where p.owner_id=v_owner and p.stock_quantity=0
    and exists(select 1 from transaction_items ti where ti.transaction_id=v_tx.id and ti.product_id=p.id);
  if p_customer_id is not null then update customers set balance=balance+(v_total-p_amount_paid),updated_at=now() where id=p_customer_id and owner_id=v_owner; end if;
  return v_tx;
end $$;

create or replace function public.record_payment(p_customer_id uuid, p_amount numeric, p_notes text default null)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid:=auth.uid(); v_tx public.transactions; v_name text;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_amount <= 0 then raise exception 'Payment must be greater than zero'; end if;
  select name into v_name from customers where id=p_customer_id and owner_id=v_owner for update;
  if not found then raise exception 'Customer not found'; end if;
  update customers set balance=balance-p_amount,updated_at=now() where id=p_customer_id and owner_id=v_owner;
  insert into transactions(owner_id,reference,type,customer_id,customer_name,total,amount_paid,notes)
  values(v_owner,'PAY-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),'payment',p_customer_id,v_name,p_amount,p_amount,p_notes) returning * into v_tx;
  return v_tx;
end $$;

create or replace function public.record_opening_balance(p_customer_id uuid, p_amount numeric)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid:=auth.uid(); v_tx public.transactions; v_name text;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_amount <= 0 then raise exception 'Opening balance must be greater than zero'; end if;
  select name into v_name from customers where id=p_customer_id and owner_id=v_owner;
  if not found then raise exception 'Customer not found'; end if;
  insert into transactions(owner_id,reference,type,customer_id,customer_name,total,notes)
  values(v_owner,'OPEN-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),'opening_balance',p_customer_id,v_name,p_amount,'Opening customer balance') returning * into v_tx;
  return v_tx;
end $$;

create or replace function public.adjust_stock(p_product_id uuid, p_delta numeric, p_notes text default null)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare v_owner uuid:=auth.uid(); v_product public.products; v_tx public.transactions;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_delta=0 then raise exception 'Stock change cannot be zero'; end if;
  select * into v_product from products where id=p_product_id and owner_id=v_owner for update;
  if not found then raise exception 'Product not found'; end if;
  if v_product.stock_quantity+p_delta<0 then raise exception 'Stock cannot go below zero'; end if;
  update products set stock_quantity=stock_quantity+p_delta where id=p_product_id and owner_id=v_owner;
  insert into transactions(owner_id,reference,type,customer_name,total,notes)
  values(v_owner,'STK-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),'stock_adjustment',v_product.name,p_delta,p_notes) returning * into v_tx;
  delete from products where id=p_product_id and owner_id=v_owner and stock_quantity=0;
  return v_tx;
end $$;

drop function if exists public.receive_purchase(text,text,date,jsonb,text);
drop function if exists public.receive_purchase(text,text,date,jsonb,jsonb,text);
drop function if exists public.receive_purchase(text,text,date,jsonb,jsonb,text,boolean);
create function public.receive_purchase(p_vendor_name text, p_invoice_number text, p_invoice_date date, p_items jsonb, p_summary jsonb, p_notes text default null, p_allow_mismatches boolean default false)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_tx public.transactions; v_item jsonb; v_product public.products;
  v_qty numeric(14,3); v_rate numeric(14,2); v_amount numeric(14,2); v_subtotal numeric(14,2):=0;
  v_discount numeric(14,2); v_net numeric(14,2); v_gst numeric(14,2); v_round numeric(14,2); v_total numeric(14,2);
  v_item_discount numeric(14,2); v_item_net numeric(14,2); v_item_gst numeric(14,2); v_item_total numeric(14,2); v_cost numeric(14,2);
  v_discount_rate numeric(8,3); v_gst_rate numeric(8,3); v_calc_amount numeric(14,2);
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if nullif(trim(p_vendor_name),'') is null or nullif(trim(p_invoice_number),'') is null then raise exception 'Vendor and invoice number are required'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Add at least one invoice line'; end if;
  if p_summary is null or jsonb_typeof(p_summary)<>'object' then raise exception 'Invoice summary is missing'; end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty:=(v_item->>'quantity')::numeric; v_rate:=(v_item->>'rate')::numeric;
    v_amount:=coalesce(nullif(v_item->>'amount','')::numeric,round(v_qty*v_rate,2));
    if v_qty<=0 or v_rate<0 or v_amount<0 then raise exception 'Invalid purchase quantity, rate, or amount'; end if;
    v_calc_amount:=round(v_qty*v_rate,2);
    if abs(v_amount-v_calc_amount)>5 and not p_allow_mismatches then raise exception 'Quantity multiplied by rate differs from the line amount by more than ₹5'; end if;
    v_subtotal:=v_subtotal+v_amount;
    if nullif(v_item->>'product_id','') is not null then
      select * into v_product from products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
      if not found then raise exception 'Inventory item not found'; end if;
    end if;
  end loop;
  v_discount:=coalesce((p_summary->>'discount_amount')::numeric,0);
  v_discount_rate:=coalesce((p_summary->>'discount_rate')::numeric,0);
  v_net:=coalesce((p_summary->>'net_value')::numeric,v_subtotal-v_discount);
  v_gst:=coalesce((p_summary->>'gst_amount')::numeric,0);
  v_gst_rate:=coalesce((p_summary->>'gst_rate')::numeric,0);
  v_round:=coalesce((p_summary->>'round_off')::numeric,0);
  v_total:=coalesce((p_summary->>'total')::numeric,v_net+v_gst+v_round);
  if v_discount<0 or v_net<0 or v_gst<0 or (v_discount>v_subtotal and not p_allow_mismatches) then raise exception 'Invalid invoice discount, net value, or GST'; end if;
  if not p_allow_mismatches and (abs(v_subtotal*(v_discount_rate-5)/100)>5 or abs(v_discount-round(v_subtotal*0.05,2))>5) then raise exception 'Discount differs from the 5 percent check by more than ₹5'; end if;
  if not p_allow_mismatches and abs(v_net-round(v_subtotal-v_discount,2))>5 then raise exception 'Net value differs from table total less discount by more than ₹5'; end if;
  if not p_allow_mismatches and (abs(v_net*(v_gst_rate-5)/100)>5 or abs(v_gst-round(v_net*0.05,2))>5) then raise exception 'Output IGST differs from 5 percent of net value by more than ₹5'; end if;
  if not p_allow_mismatches and abs(v_total-(v_net+v_gst+v_round))>5 then raise exception 'Invoice total differs by more than ₹5'; end if;

  insert into transactions(owner_id,reference,type,customer_name,vendor_name,invoice_number,invoice_date,subtotal,discount_rate,discount_amount,net_value,tax,gst_label,gst_rate,round_off,total,discount_verified,net_value_verified,gst_verified,total_verified,notes)
  values(v_owner,'PUR-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),'purchase',trim(p_vendor_name),trim(p_vendor_name),trim(p_invoice_number),p_invoice_date,
    v_subtotal,v_discount_rate,v_discount,v_net,v_gst,coalesce(nullif(trim(p_summary->>'gst_label'),''),'Output IGST'),v_gst_rate,v_round,v_total,
    abs(v_subtotal*(v_discount_rate-5)/100)<=5 and abs(v_discount-round(v_subtotal*0.05,2))<=5,
    abs(v_net-round(v_subtotal-v_discount,2))<=5,
    abs(v_net*(v_gst_rate-5)/100)<=5 and abs(v_gst-round(v_net*0.05,2))<=5,
    abs(v_total-(v_net+v_gst+v_round))<=5,p_notes)
  returning * into v_tx;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty:=(v_item->>'quantity')::numeric; v_rate:=(v_item->>'rate')::numeric;
    v_amount:=coalesce(nullif(v_item->>'amount','')::numeric,round(v_qty*v_rate,2));
    if nullif(v_item->>'product_id','') is not null then
      select * into v_product from products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
      if not found then raise exception 'Inventory item not found'; end if;
    else
      select * into v_product from products where owner_id=v_owner and name=coalesce(nullif(trim(v_item->>'product_name'),''),'Invoice item') and unit=coalesce(nullif(trim(v_item->>'unit'),''),'unit') order by created_at limit 1 for update;
      if not found then
        insert into products(owner_id,name,unit,stock_quantity,retail_price,wholesale_price,cost_price)
        values(v_owner,coalesce(nullif(trim(v_item->>'product_name'),''),'Invoice item'),coalesce(nullif(trim(v_item->>'unit'),''),'unit'),0,coalesce((v_item->>'mrp')::numeric,0),0,0)
        returning * into v_product;
      end if;
    end if;
    v_item_discount:=case when v_subtotal=0 then 0 else round(v_discount*v_amount/v_subtotal,2) end;
    v_item_net:=v_amount-v_item_discount;
    v_item_gst:=case when v_net=0 then 0 else round(v_gst*v_item_net/v_net,2) end;
    v_item_total:=v_item_net+v_item_gst;
    v_cost:=coalesce(nullif(v_item->>'cost_price','')::numeric,round(v_rate*0.95*1.05,2));
    update products set name=coalesce(nullif(trim(v_item->>'product_name'),''),name),cost_price=case when stock_quantity+v_qty=0 then v_cost else round((stock_quantity*cost_price+v_qty*v_cost)/(stock_quantity+v_qty),2) end,
      stock_quantity=stock_quantity+v_qty, mrp=coalesce(nullif(v_item->>'mrp','')::numeric,mrp), purchase_rate=v_rate,last_purchase_date=coalesce(p_invoice_date,current_date),
      rate_discount_percent=coalesce(nullif(v_item->>'rate_discount_percent','')::numeric,case when coalesce((v_item->>'mrp')::numeric,0)>0 then round((1-v_rate/(v_item->>'mrp')::numeric)*100,3) else 0 end),
      dealer_discount_percent=coalesce(nullif(v_item->>'dealer_discount_percent','')::numeric,case when coalesce((v_item->>'mrp')::numeric,0)>0 then round((1-v_cost/(v_item->>'mrp')::numeric)*100,3) else 0 end),
      retail_price=case when retail_price=0 and coalesce((v_item->>'mrp')::numeric,0)>0 then (v_item->>'mrp')::numeric else retail_price end
      where id=v_product.id and owner_id=v_owner;
    insert into transaction_items(owner_id,transaction_id,product_id,product_name,quantity,unit_price,line_total,hsn,case_count,pairs_per_case,mrp,unit,discount_amount,net_value,gst_amount,item_total,calculated_amount,amount_verified,rate_discount_percent,cost_price,dealer_discount_percent)
      values(v_owner,v_tx.id,v_product.id,coalesce(nullif(trim(v_item->>'product_name'),''),v_product.name),v_qty,v_rate,v_amount,null,
        coalesce((v_item->>'case_count')::numeric,0),coalesce((v_item->>'pairs_per_case')::numeric,0),coalesce((v_item->>'mrp')::numeric,0),nullif(trim(v_item->>'unit'),''),
        v_item_discount,v_item_net,v_item_gst,v_item_total,round(v_qty*v_rate,2),abs(v_amount-round(v_qty*v_rate,2))<=5,
        coalesce((v_item->>'rate_discount_percent')::numeric,case when coalesce((v_item->>'mrp')::numeric,0)>0 then round((1-v_rate/(v_item->>'mrp')::numeric)*100,3) else 0 end),v_cost,
        coalesce((v_item->>'dealer_discount_percent')::numeric,case when coalesce((v_item->>'mrp')::numeric,0)>0 then round((1-v_cost/(v_item->>'mrp')::numeric)*100,3) else 0 end));
  end loop;
  return v_tx;
end $$;

revoke all on function public.complete_sale(text,uuid,jsonb,numeric,numeric,text) from public;
revoke all on function public.complete_sale(text,uuid,jsonb,numeric,numeric,text) from authenticated;
drop function if exists public.complete_wholesale_sale(uuid,numeric,jsonb,numeric,text);
create or replace function public.complete_wholesale_sale(p_customer_id uuid,p_discount_rate numeric,p_extra_discount_rate numeric,p_payment_days integer,p_print_discount_rate boolean,p_items jsonb,p_amount_paid numeric)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_tx public.transactions; v_customer public.customers; v_item jsonb; v_product public.products;
  v_qty numeric(14,3); v_line_discount numeric(8,3); v_inclusive numeric(14,2); v_price numeric(14,2); v_gst numeric(14,2);
  v_subtotal numeric(14,2):=0; v_tax numeric(14,2):=0; v_total numeric(14,2):=0; v_discount numeric(14,2):=0;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_customer_id is null then raise exception 'Select a registered customer'; end if;
  if p_discount_rate is null or p_discount_rate<0 or p_discount_rate>=100 then raise exception 'Customer discount must be from 0%% to less than 100%%'; end if;
  if p_extra_discount_rate is null or p_extra_discount_rate<0 or p_extra_discount_rate>=100 then raise exception 'Plus discount must be from 0%% to less than 100%%'; end if;
  if p_payment_days<0 or (p_extra_discount_rate>0 and p_payment_days<=0) then raise exception 'Enter the number of days allowed for the plus discount'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Add at least one item'; end if;
  select * into v_customer from public.customers where id=p_customer_id and owner_id=v_owner for update;
  if not found then raise exception 'Registered customer not found'; end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty:=(v_item->>'quantity')::numeric;
    if v_qty<=0 then raise exception 'Quantity must be greater than zero'; end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
    if not found then raise exception 'Product not found'; end if;
    if v_product.stock_quantity<v_qty then raise exception 'Not enough stock for %',v_product.name; end if;
    if v_product.mrp<=0 then raise exception 'MRP is missing for %',v_product.name; end if;
    v_line_discount:=coalesce(nullif(v_item->>'discount_rate','')::numeric,p_discount_rate);
    if v_line_discount<0 or v_line_discount>=100 then raise exception 'Item discount must be from 0%% to less than 100%%'; end if;
    v_inclusive:=round(v_product.mrp*(1-v_line_discount/100),2);
    v_price:=round(v_inclusive/1.05,2); v_gst:=v_inclusive-v_price;
    v_subtotal:=v_subtotal+round(v_price*v_qty,2);
    v_tax:=v_tax+round(v_gst*v_qty,2);
    v_total:=v_total+round(v_inclusive*v_qty,2);
    v_discount:=v_discount+round((v_product.mrp-v_inclusive)*v_qty,2);
  end loop;
  if p_amount_paid is null or p_amount_paid<=0 or p_amount_paid>v_total then raise exception 'Enter payment received now, greater than zero and no more than the bill total'; end if;
  insert into public.transactions(owner_id,reference,type,sale_type,customer_id,customer_name,subtotal,tax,total,amount_paid,discount_rate,discount_amount,net_value,gst_label,gst_rate,round_off,extra_discount_rate,payment_days,discount_due_date,early_payment_discount,print_discount_rate)
  values(v_owner,'BILL-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),'sale','wholesale',v_customer.id,v_customer.name,v_subtotal,v_tax,v_total,p_amount_paid,p_discount_rate,v_discount,v_subtotal,'GST included',5,0,p_extra_discount_rate,p_payment_days,case when p_payment_days>0 then current_date+p_payment_days else null end,round(v_total*p_extra_discount_rate/100,2),coalesce(p_print_discount_rate,true))
  returning * into v_tx;
  for v_item in select value from jsonb_array_elements(p_items) loop
    v_qty:=(v_item->>'quantity')::numeric;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
    v_line_discount:=coalesce(nullif(v_item->>'discount_rate','')::numeric,p_discount_rate);
    v_inclusive:=round(v_product.mrp*(1-v_line_discount/100),2); v_price:=round(v_inclusive/1.05,2); v_gst:=v_inclusive-v_price;
    insert into public.transaction_items(owner_id,transaction_id,product_id,product_name,quantity,unit_price,line_total,mrp,unit,discount_amount,net_value,gst_amount,item_total,calculated_amount,amount_verified,sale_discount_rate,inventory_ref,dealer_discount_percent)
    values(v_owner,v_tx.id,v_product.id,v_product.name,v_qty,v_price,round(v_price*v_qty,2),v_product.mrp,v_product.unit,
      round((v_product.mrp-v_inclusive)*v_qty,2),round(v_price*v_qty,2),round(v_gst*v_qty,2),round(v_inclusive*v_qty,2),round(v_price*v_qty,2),true,v_line_discount,v_product.id,v_product.dealer_discount_percent);
    update public.products set stock_quantity=stock_quantity-v_qty where id=v_product.id and owner_id=v_owner;
  end loop;
  update public.customers set balance=balance+(v_total-p_amount_paid),updated_at=now() where id=v_customer.id and owner_id=v_owner;
  delete from public.products p where p.owner_id=v_owner and p.stock_quantity=0 and exists(select 1 from public.transaction_items ti where ti.transaction_id=v_tx.id and ti.product_id=p.id);
  return v_tx;
end $$;
revoke all on function public.complete_wholesale_sale(uuid,numeric,numeric,integer,boolean,jsonb,numeric) from public;
grant execute on function public.complete_wholesale_sale(uuid,numeric,numeric,integer,boolean,jsonb,numeric) to authenticated;
create or replace function public.revise_wholesale_sale(p_transaction_id uuid,p_discount_rate numeric,p_extra_discount_rate numeric,p_payment_days integer,p_print_discount_rate boolean,p_amount_paid numeric,p_items jsonb)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_tx public.transactions; v_customer public.customers; v_line public.transaction_items; v_item jsonb; v_product public.products;
  v_qty numeric(14,3); v_delta numeric(14,3); v_line_discount numeric(8,3); v_inclusive numeric(14,2); v_price numeric(14,2); v_gst numeric(14,2);
  v_subtotal numeric(14,2):=0; v_tax numeric(14,2):=0; v_total numeric(14,2):=0; v_discount numeric(14,2):=0; v_old_due numeric(14,2);
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  select * into v_tx from public.transactions where id=p_transaction_id and owner_id=v_owner and type='sale' and sale_type='wholesale' for update;
  if not found then raise exception 'Wholesale invoice not found'; end if;
  select * into v_customer from public.customers where id=v_tx.customer_id and owner_id=v_owner for update;
  if not found then raise exception 'Invoice customer not found'; end if;
  if p_discount_rate<0 or p_discount_rate>=100 or p_extra_discount_rate<0 or p_extra_discount_rate>=100 or p_payment_days<0 then raise exception 'Discount and payment terms are invalid'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Invoice must contain at least one item'; end if;
  v_old_due:=v_tx.total-v_tx.amount_paid;
  for v_item in select value from jsonb_array_elements(p_items) loop
    select * into v_line from public.transaction_items where id=(v_item->>'transaction_item_id')::uuid and transaction_id=v_tx.id and owner_id=v_owner for update;
    if not found then raise exception 'Invoice line not found'; end if;
    v_qty:=(v_item->>'quantity')::numeric; v_line_discount:=coalesce((v_item->>'discount_rate')::numeric,p_discount_rate);
    if v_qty<=0 or v_line_discount<0 or v_line_discount>=100 then raise exception 'Enter a positive quantity and an item discount below 100%%'; end if;
    v_delta:=v_line.quantity-v_qty;
    select * into v_product from public.products where id=coalesce(v_line.inventory_ref,v_line.product_id) and owner_id=v_owner for update;
    if found then
      if v_delta<0 and v_product.stock_quantity < -v_delta then raise exception 'There is not enough remaining stock to increase %',v_line.product_name; end if;
      update public.products set stock_quantity=stock_quantity+v_delta where id=v_product.id and owner_id=v_owner;
      update public.transaction_items set product_id=v_product.id,inventory_ref=v_product.id where id=v_line.id;
    elsif v_delta>0 then
      insert into public.products(id,owner_id,name,unit,stock_quantity,mrp,retail_price,cost_price,dealer_discount_percent)
      values(coalesce(v_line.inventory_ref,gen_random_uuid()),v_owner,v_line.product_name,coalesce(v_line.unit,'unit'),v_delta,v_line.mrp,v_line.mrp,0,v_line.dealer_discount_percent)
      returning * into v_product;
      update public.transaction_items set product_id=v_product.id,inventory_ref=v_product.id where id=v_line.id;
    elsif v_delta<0 then raise exception 'There is no remaining inventory record for %; receive the stock before increasing this invoice quantity',v_line.product_name;
    end if;
    v_inclusive:=round(v_line.mrp*(1-v_line_discount/100),2); v_price:=round(v_inclusive/1.05,2); v_gst:=v_inclusive-v_price;
    v_subtotal:=v_subtotal+round(v_price*v_qty,2); v_tax:=v_tax+round(v_gst*v_qty,2); v_total:=v_total+round(v_inclusive*v_qty,2);
    v_discount:=v_discount+round((v_line.mrp-v_inclusive)*v_qty,2);
    update public.transaction_items set quantity=v_qty,sale_discount_rate=v_line_discount,unit_price=v_price,line_total=round(v_price*v_qty,2),
      discount_amount=round((v_line.mrp-v_inclusive)*v_qty,2),net_value=round(v_price*v_qty,2),gst_amount=round(v_gst*v_qty,2),
      item_total=round(v_inclusive*v_qty,2),calculated_amount=round(v_price*v_qty,2),amount_verified=true where id=v_line.id;
  end loop;
  if p_amount_paid<0 or p_amount_paid>v_total then raise exception 'Payment received cannot exceed the revised invoice total'; end if;
  update public.transactions set subtotal=v_subtotal,tax=v_tax,total=v_total,amount_paid=p_amount_paid,discount_rate=p_discount_rate,
    discount_amount=v_discount,net_value=v_subtotal,extra_discount_rate=p_extra_discount_rate,payment_days=p_payment_days,
    discount_due_date=case when p_payment_days>0 then created_at::date+p_payment_days else null end,
    early_payment_discount=round(v_total*p_extra_discount_rate/100,2),print_discount_rate=coalesce(p_print_discount_rate,true)
    where id=v_tx.id and owner_id=v_owner returning * into v_tx;
  update public.customers set balance=balance+(v_total-p_amount_paid-v_old_due),updated_at=now() where id=v_customer.id and owner_id=v_owner;
  delete from public.products where owner_id=v_owner and stock_quantity=0;
  return v_tx;
end $$;
revoke all on function public.revise_wholesale_sale(uuid,numeric,numeric,integer,boolean,numeric,jsonb) from public;
grant execute on function public.revise_wholesale_sale(uuid,numeric,numeric,integer,boolean,numeric,jsonb) to authenticated;
revoke all on function public.record_payment(uuid,numeric,text) from public;
grant execute on function public.record_payment(uuid,numeric,text) to authenticated;
revoke all on function public.record_opening_balance(uuid,numeric) from public;
grant execute on function public.record_opening_balance(uuid,numeric) to authenticated;
revoke all on function public.adjust_stock(uuid,numeric,text) from public;
grant execute on function public.adjust_stock(uuid,numeric,text) to authenticated;
revoke all on function public.receive_purchase(text,text,date,jsonb,jsonb,text,boolean) from public;
grant execute on function public.receive_purchase(text,text,date,jsonb,jsonb,text,boolean) to authenticated;
create or replace function public.refresh_purchase_product(p_product_id uuid, p_owner_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_line record;
begin
  select ti.product_name,ti.unit,ti.mrp,ti.unit_price,ti.rate_discount_percent,ti.cost_price,ti.dealer_discount_percent,coalesce(tx.invoice_date,tx.created_at::date) as purchase_date
    into v_line from public.transaction_items ti join public.transactions tx on tx.id=ti.transaction_id
    where ti.product_id=p_product_id and ti.owner_id=p_owner_id and tx.owner_id=p_owner_id and tx.type='purchase'
    order by tx.created_at desc,tx.id desc,ti.id desc limit 1;
  if found then
    update public.products as p set name=v_line.product_name,unit=coalesce(nullif(v_line.unit,''),p.unit),mrp=v_line.mrp,
      purchase_rate=v_line.unit_price,rate_discount_percent=v_line.rate_discount_percent,cost_price=v_line.cost_price,
      dealer_discount_percent=v_line.dealer_discount_percent,last_purchase_date=v_line.purchase_date
      where id=p_product_id and owner_id=p_owner_id;
  else
    update public.products set mrp=0,purchase_rate=0,rate_discount_percent=0,cost_price=0,dealer_discount_percent=0,last_purchase_date=null
      where id=p_product_id and owner_id=p_owner_id;
  end if;
end $$;
revoke all on function public.refresh_purchase_product(uuid,uuid) from public;
drop function if exists public.delete_purchase(uuid);
create function public.delete_purchase(p_transaction_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_tx public.transactions; v_line record; v_product public.products; v_product_ids uuid[]:=array[]::uuid[]; v_product_id uuid;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  select * into v_tx from public.transactions
    where id=p_transaction_id and owner_id=v_owner and type='purchase' for update;
  if not found then raise exception 'Purchase bill not found'; end if;

  for v_line in
    select product_id, quantity, product_name
      from public.transaction_items
      where transaction_id=v_tx.id and owner_id=v_owner and product_id is not null
      order by product_id
  loop
    if not (v_line.product_id=any(v_product_ids)) then v_product_ids:=array_append(v_product_ids,v_line.product_id); end if;
    select * into v_product from public.products
      where id=v_line.product_id and owner_id=v_owner for update;
    if found then
      if v_product.stock_quantity<v_line.quantity then
        raise exception 'Cannot delete this bill: stock for % is below the quantity received on this invoice. Reconcile the stock first.',v_line.product_name;
      end if;
      update public.products
        set stock_quantity=stock_quantity-v_line.quantity
        where id=v_product.id and owner_id=v_owner;
    end if;
  end loop;

  delete from public.products where owner_id=v_owner and id=any(v_product_ids);
  delete from public.transactions where id=v_tx.id and owner_id=v_owner;
  foreach v_product_id in array v_product_ids loop
    perform public.refresh_purchase_product(v_product_id,v_owner);
  end loop;
end $$;
revoke all on function public.delete_purchase(uuid) from public;
grant execute on function public.delete_purchase(uuid) to authenticated;
drop function if exists public.update_purchase(uuid,text,text,date,jsonb,jsonb,boolean);
create function public.update_purchase(p_transaction_id uuid,p_vendor_name text,p_invoice_number text,p_invoice_date date,p_items jsonb,p_summary jsonb,p_allow_mismatches boolean default false)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_old public.transactions; v_new public.transactions; v_line record; v_product public.products;
  v_item jsonb; v_seen uuid[]:=array[]::uuid[]; v_product_id uuid;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  select * into v_old from public.transactions where id=p_transaction_id and owner_id=v_owner and type='purchase' for update;
  if not found then raise exception 'Purchase bill not found'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Add at least one invoice line'; end if;
  if jsonb_array_length(p_items)<>(select count(*) from public.transaction_items where transaction_id=v_old.id and owner_id=v_owner) then
    raise exception 'Invoice line count changed; add or remove lines using a new purchase bill';
  end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    if nullif(v_item->>'id','') is null then raise exception 'A saved invoice line is missing its ID'; end if;
    if (v_item->>'id')::uuid=any(v_seen) then raise exception 'Duplicate invoice line'; end if;
    v_seen:=array_append(v_seen,(v_item->>'id')::uuid);
    select * into v_line from public.transaction_items where id=(v_item->>'id')::uuid and transaction_id=v_old.id and owner_id=v_owner;
    if not found then raise exception 'Invoice line does not belong to this bill'; end if;
    if v_item->>'product_id' is distinct from v_line.product_id::text then raise exception 'Inventory item mapping cannot be changed from invoice edit'; end if;
  end loop;

  select * into v_new from public.receive_purchase(p_vendor_name,p_invoice_number,p_invoice_date,p_items,p_summary,v_old.notes,p_allow_mismatches);

  for v_line in select product_id,quantity,product_name from public.transaction_items where transaction_id=v_old.id and owner_id=v_owner and product_id is not null order by product_id loop
    select * into v_product from public.products where id=v_line.product_id and owner_id=v_owner for update;
    if found then
      if v_product.stock_quantity<v_line.quantity then raise exception 'Invoice edit would make stock negative for %',v_line.product_name; end if;
      update public.products set stock_quantity=stock_quantity-v_line.quantity where id=v_product.id and owner_id=v_owner;
    end if;
  end loop;

  update public.transactions old_tx set customer_name=v_new.customer_name,vendor_name=v_new.vendor_name,invoice_number=v_new.invoice_number,
    invoice_date=v_new.invoice_date,subtotal=v_new.subtotal,discount_rate=v_new.discount_rate,discount_amount=v_new.discount_amount,
    net_value=v_new.net_value,tax=v_new.tax,gst_label=v_new.gst_label,gst_rate=v_new.gst_rate,round_off=v_new.round_off,total=v_new.total,
    discount_verified=v_new.discount_verified,net_value_verified=v_new.net_value_verified,gst_verified=v_new.gst_verified,
    total_verified=v_new.total_verified,notes=v_new.notes where old_tx.id=v_old.id and old_tx.owner_id=v_owner;
  delete from public.transaction_items where transaction_id=v_old.id and owner_id=v_owner;
  update public.transaction_items set transaction_id=v_old.id where transaction_id=v_new.id and owner_id=v_owner;
  delete from public.transactions where id=v_new.id and owner_id=v_owner;

  for v_product_id in select distinct product_id from public.transaction_items where transaction_id=v_old.id and owner_id=v_owner and product_id is not null loop
    perform public.refresh_purchase_product(v_product_id,v_owner);
  end loop;
  select * into v_old from public.transactions where id=p_transaction_id and owner_id=v_owner;
  return v_old;
end $$;
revoke all on function public.update_purchase(uuid,text,text,date,jsonb,jsonb,boolean) from public;
grant execute on function public.update_purchase(uuid,text,text,date,jsonb,jsonb,boolean) to authenticated;
revoke all on function public.activate_ai_model(uuid) from public;
grant execute on function public.activate_ai_model(uuid) to authenticated;
notify pgrst, 'reload schema';
