-- Track retail item returns independently from the original sale quantity.
alter table public.transaction_items
  add column if not exists returned_quantity numeric(14,3) not null default 0;
alter table public.transaction_items add column if not exists inventory_article_number text;
alter table public.transaction_items add column if not exists inventory_colour text;
alter table public.transaction_items add column if not exists inventory_size text;
alter table public.transaction_items add column if not exists inventory_purchase_rate numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists inventory_rate_discount_percent numeric(8,3) not null default 0;
alter table public.transaction_items add column if not exists inventory_gst_amount numeric(14,2) not null default 0;
alter table public.transaction_items add column if not exists inventory_retail_price numeric(14,2) not null default 0;
update public.transaction_items ti set inventory_article_number=p.article_number,inventory_colour=p.colour,inventory_size=p.size,inventory_purchase_rate=p.purchase_rate,inventory_rate_discount_percent=p.rate_discount_percent,inventory_gst_amount=p.gst_amount,inventory_retail_price=p.retail_price from public.products p where p.id=ti.inventory_ref and p.owner_id=ti.owner_id and ti.inventory_article_number is null;

create or replace function public.save_retail_entry(p_mode text,p_sale_date date,p_items jsonb)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_tx public.transactions; v_item jsonb; v_product public.products;
  v_qty numeric(14,3); v_sale numeric(14,2); v_cost numeric(14,2); v_gst numeric(14,2); v_input_gst numeric(14,2):=0; v_base numeric(14,2);
  v_subtotal numeric(14,2):=0; v_tax numeric(14,2):=0; v_total numeric(14,2):=0; v_name text; v_unit text; v_product_id uuid;
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_mode not in ('walkmate','general') then raise exception 'Choose Walkmate Retail or General Retail'; end if;
  if p_sale_date is null then raise exception 'Sale date is required'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)<>1 then raise exception 'Save one retail item per entry'; end if;
  v_item:=p_items->0; v_qty:=coalesce(nullif(v_item->>'quantity','')::numeric,0);
  if v_qty<=0 then raise exception 'Quantity must be greater than zero'; end if;
  v_sale:=coalesce(nullif(v_item->>'sale_price','')::numeric,0);
  if v_sale<=0 then raise exception 'Sale price must be greater than zero'; end if;
  if p_mode='walkmate' then
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and owner_id=v_owner for update;
    if not found then raise exception 'Select an item from inventory'; end if;
    if v_product.stock_quantity<v_qty then raise exception 'Only % units remain in inventory',v_product.stock_quantity; end if;
    v_name:=v_product.name; v_unit:=v_product.unit; v_cost:=v_product.cost_price; v_product_id:=v_product.id;
    v_gst:=round(v_sale-v_sale/1.05,2); v_input_gst:=round(v_cost*5/105,2); v_base:=v_sale-v_gst;
  else
    v_name:=trim(coalesce(v_item->>'product_name','')); v_unit:='unit'; v_product_id:=null;
    v_cost:=coalesce(nullif(v_item->>'cost_price','')::numeric,0);
    if v_name='' or v_cost<=0 then raise exception 'Enter item sold and a positive cost price'; end if;
    v_gst:=0; v_base:=v_sale;
  end if;
  v_subtotal:=round(v_base*v_qty,2); v_tax:=round(v_gst*v_qty,2); v_total:=round(v_sale*v_qty,2);
  insert into public.transactions(owner_id,reference,type,sale_type,customer_name,invoice_date,subtotal,tax,total,amount_paid,gst_label,gst_rate,payment_method)
  values(v_owner,'RTL-'||to_char(p_sale_date,'YYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)),'sale','retail',case when p_mode='walkmate' then 'Walkmate Retail' else 'General Retail' end,p_sale_date,v_subtotal,v_tax,v_total,v_total,case when p_mode='walkmate' then 'CGST + SGST' else null end,case when p_mode='walkmate' then 5 else 0 end,null)
  returning * into v_tx;
  insert into public.transaction_items(owner_id,transaction_id,product_id,inventory_ref,product_name,quantity,unit_price,line_total,mrp,unit,net_value,gst_amount,input_gst_amount,item_total,cost_price,inventory_article_number,inventory_colour,inventory_size,inventory_purchase_rate,inventory_rate_discount_percent,inventory_gst_amount,inventory_retail_price)
  values(v_owner,v_tx.id,v_product_id,v_product_id,v_name,v_qty,v_base,v_subtotal,coalesce(v_product.mrp,0),v_unit,v_subtotal,v_tax,round(v_input_gst*v_qty,2),v_total,v_cost,v_product.article_number,v_product.colour,v_product.size,v_product.purchase_rate,v_product.rate_discount_percent,v_product.gst_amount,v_product.retail_price);
  if p_mode='walkmate' then
    update public.products set stock_quantity=stock_quantity-v_qty where id=v_product.id and owner_id=v_owner;
    delete from public.products where id=v_product.id and owner_id=v_owner and stock_quantity=0;
  end if;
  return v_tx;
end $$;
revoke all on function public.save_retail_entry(text,date,jsonb) from public;
grant execute on function public.save_retail_entry(text,date,jsonb) to authenticated;

create or replace function public.return_walkmate_retail_item(p_transaction_item_id uuid,p_quantity numeric)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_line public.transaction_items; v_tx public.transactions; v_product public.products;
  v_product_id uuid; v_sold numeric(14,3); v_returned numeric(14,3); v_remaining numeric(14,3);
  v_per_total numeric(14,2); v_per_net numeric(14,2); v_per_tax numeric(14,2); v_per_input numeric(14,2);
  v_new_subtotal numeric(14,2); v_new_tax numeric(14,2); v_new_total numeric(14,2);
begin
  if v_owner is null then raise exception 'Sign in required'; end if;
  if p_quantity is null or p_quantity<=0 then raise exception 'Return quantity must be greater than zero'; end if;
  select * into v_line from public.transaction_items where id=p_transaction_item_id and owner_id=v_owner for update;
  if not found then raise exception 'Retail item was not found'; end if;
  select * into v_tx from public.transactions where id=v_line.transaction_id and owner_id=v_owner and type='sale' and sale_type='retail' and customer_name='Walkmate Retail' for update;
  if not found then raise exception 'Walkmate Retail sale was not found'; end if;
  v_sold:=coalesce(v_line.quantity,0); v_returned:=coalesce(v_line.returned_quantity,0); v_remaining:=v_sold-v_returned;
  if p_quantity>v_remaining then raise exception 'Return quantity exceeds the unreturned quantity'; end if;
  if v_remaining<=0 then raise exception 'This item has already been returned'; end if;

  v_product_id:=coalesce(v_line.inventory_ref,v_line.product_id);
  if v_product_id is null then raise exception 'Original inventory article reference is missing'; end if;
  select * into v_product from public.products where id=v_product_id and owner_id=v_owner for update;
  if found then
    update public.products set stock_quantity=stock_quantity+p_quantity where id=v_product_id and owner_id=v_owner;
  else
    insert into public.products(id,owner_id,name,unit,stock_quantity,mrp,purchase_rate,rate_discount_percent,gst_amount,cost_price,dealer_discount_percent,retail_price,article_number,colour,size)
    values(v_product_id,v_owner,v_line.product_name,coalesce(v_line.unit,'unit'),p_quantity,coalesce(v_line.mrp,0),coalesce(nullif(v_line.inventory_purchase_rate,0),round(coalesce(v_line.mrp,0)*0.60,2)),
      coalesce(nullif(v_line.inventory_rate_discount_percent,0),40),coalesce(nullif(v_line.inventory_gst_amount,0),round(coalesce(v_line.mrp,0)*0.60*0.95*0.05,2)),coalesce(v_line.cost_price,0),coalesce(v_line.dealer_discount_percent,0),
      coalesce(nullif(v_line.inventory_retail_price,0),v_line.mrp),v_line.inventory_article_number,v_line.inventory_colour,v_line.inventory_size);
  end if;

  v_per_total:=round(coalesce(v_line.item_total,0)/v_remaining,2);
  v_per_net:=round(coalesce(v_line.net_value,0)/v_remaining,2);
  v_per_tax:=round(coalesce(v_line.gst_amount,0)/v_remaining,2);
  v_per_input:=round(coalesce(v_line.input_gst_amount,0)/v_remaining,2);
  update public.transaction_items set returned_quantity=v_returned+p_quantity,
    item_total=greatest(0,item_total-round(v_per_total*p_quantity,2)),
    line_total=greatest(0,line_total-round(v_per_net*p_quantity,2)),
    net_value=greatest(0,net_value-round(v_per_net*p_quantity,2)),
    gst_amount=greatest(0,gst_amount-round(v_per_tax*p_quantity,2)),
    input_gst_amount=greatest(0,input_gst_amount-round(v_per_input*p_quantity,2))
    where id=v_line.id and owner_id=v_owner;
  select coalesce(sum(net_value),0),coalesce(sum(gst_amount),0),coalesce(sum(item_total),0)
    into v_new_subtotal,v_new_tax,v_new_total
    from public.transaction_items where transaction_id=v_tx.id and owner_id=v_owner;
  update public.transactions set subtotal=v_new_subtotal,net_value=v_new_subtotal,tax=v_new_tax,total=v_new_total,amount_paid=v_new_total
    where id=v_tx.id and owner_id=v_owner returning * into v_tx;
  return v_tx;
end $$;
revoke all on function public.return_walkmate_retail_item(uuid,numeric) from public;
grant execute on function public.return_walkmate_retail_item(uuid,numeric) to authenticated;

create or replace function public.delete_general_retail_entry(p_transaction_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  delete from public.transactions
   where id=p_transaction_id and owner_id=auth.uid() and type='sale' and sale_type='retail' and customer_name='General Retail';
  if not found then raise exception 'General Retail entry was not found'; end if;
end $$;
revoke all on function public.delete_general_retail_entry(uuid) from public;
grant execute on function public.delete_general_retail_entry(uuid) to authenticated;

notify pgrst, 'reload schema';
