-- Make General Retail saves independent of an inventory product row.
-- Existing deployments: run this migration once in the Supabase SQL Editor.
create or replace function public.save_retail_entry(p_mode text,p_sale_date date,p_items jsonb)
returns public.transactions language plpgsql security definer set search_path=public,pg_temp as $$
declare
  v_owner uuid:=auth.uid(); v_tx public.transactions; v_item jsonb; v_product public.products;
  v_qty numeric(14,3); v_sale numeric(14,2); v_cost numeric(14,2); v_gst numeric(14,2); v_input_gst numeric(14,2):=0; v_base numeric(14,2);
  v_subtotal numeric(14,2):=0; v_tax numeric(14,2):=0; v_total numeric(14,2):=0;
  v_name text; v_unit text; v_product_id uuid; v_mrp numeric(14,2):=0;
  v_article_number text; v_colour text; v_size text; v_purchase_rate numeric(14,2):=0;
  v_rate_discount numeric(8,3):=0; v_inventory_gst numeric(14,2):=0; v_retail_price numeric(14,2):=0;
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
    v_mrp:=v_product.mrp; v_article_number:=v_product.article_number; v_colour:=v_product.colour; v_size:=v_product.size;
    v_purchase_rate:=v_product.purchase_rate; v_rate_discount:=v_product.rate_discount_percent;
    v_inventory_gst:=v_product.gst_amount; v_retail_price:=v_product.retail_price;
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
  values(v_owner,v_tx.id,v_product_id,v_product_id,v_name,v_qty,v_base,v_subtotal,v_mrp,v_unit,v_subtotal,v_tax,round(v_input_gst*v_qty,2),v_total,v_cost,v_article_number,v_colour,v_size,v_purchase_rate,v_rate_discount,v_inventory_gst,v_retail_price);

  if p_mode='walkmate' then
    update public.products set stock_quantity=stock_quantity-v_qty where id=v_product.id and owner_id=v_owner;
    delete from public.products where id=v_product.id and owner_id=v_owner and stock_quantity=0;
  end if;
  return v_tx;
end $$;
revoke all on function public.save_retail_entry(text,date,jsonb) from public;
grant execute on function public.save_retail_entry(text,date,jsonb) to authenticated;
notify pgrst, 'reload schema';
