# Om Sri Laxmi Traders Store Desk

A small-store point-of-sale and inventory web app. It supports separate retail and wholesale prices, stock tracking, bills, partial customer payments, customer balances, and transaction history. Sale completion runs as one database transaction: it checks stock, records bill lines, deducts stock, and updates the customer balance together. Purchase bills extracts invoice number/date, product description, case count, pairs per case, MRP, quantity, unit, rate, amount, invoice discount, net value, GST, round-off, and total through the active saved model profile. It does not retain HSN. The review shows MRP and the rate discount below MRP, calculates Cost Price as Rate × 0.95 × 1.05 (5% discount, then 5% GST) and Dealer Discount as (MRP − Cost Price) ÷ MRP × 100, checks quantity × rate against the invoice amount, and verifies the invoice totals before saving. No manual inventory mapping is required; each accepted line is matched or added by item name. Saved invoices can be edited or deleted. Deleting an invoice also deletes its linked product records from inventory; any remaining stock on those products is removed too. Products at zero stock are removed automatically.

## Connect the database

1. Create a Supabase project and open its SQL Editor.
2. Run [`supabase/schema.sql`](supabase/schema.sql) in the SQL Editor. Re-run it when app updates add database columns or change database functions.
3. In Supabase Authentication, create the store owner's user. Leave public sign-up disabled. To enable Google sign-in, create a Google OAuth Web client, configure its callback URI as `https://jvyjchowehtrazpwtxhq.supabase.co/auth/v1/callback`, and add its client ID and secret under Supabase Authentication → Providers → Google. Add your local and deployed app URLs to Supabase Authentication → URL Configuration → Redirect URLs.
4. Copy `.env.example` to `.env` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` from the Supabase project settings. The anon key is intended for browser use; do not put a service-role key in this app.
5. Install packages and start the local preview with `npm install` and `npm run dev`.

The database policies limit records to the signed-in owner. Sales, payments, stock corrections, purchase receipts, invoice edits, and invoice deletion are committed through database functions. AI model profiles, endpoints, model names, API formats, authentication settings, extra headers, and API keys are stored in the owner-only `ai_model_profiles` table and managed in Settings. The extractor supports OpenAI Chat Completions, OpenAI Responses, Anthropic Messages, and Google Gemini request formats, with endpoint-based auto-detection and manual overrides. The selected active model receives extracted PDF text when a purchase bill is uploaded. The endpoint must support browser CORS. This version extracts selectable text from PDFs; scanned-image PDFs need OCR and are not supported yet. Rerun `supabase/schema.sql` on an existing project after updates to add purchase detail fields, mismatch overrides, the 5% GST cost calculation (including recalculation of saved purchase costs), dealer discount fields, and purchase edit/delete functions, and cleanup of zero-stock products.

## Publish online

This app is a static Vite site and can be published on Vercel, Netlify, or another static host. For Vercel, import this folder, set the build command to `npm run build`, the output directory to `dist`, and add the two `VITE_SUPABASE_*` environment variables from the local setup. Add a custom domain through the host's domain settings when you have one.

## First use

- Add products with their opening stock and both prices.
- Add customers.
- Use **New bill** to create retail or wholesale bills, enter the amount received, and leave any unpaid remainder on the customer's account.
- Record later customer payments from the Customers page.
- Use **Purchase bills** to upload a vendor PDF, review the extracted details, then receive stock. Use the invoice edit/delete actions in purchase history to keep saved bills and inventory in sync.
- Use **Adjust stock** to record a restock or correction.
- Set the display currency and tax rate in Store settings.

Tax is configurable and starts at zero. Confirm the correct treatment for the store's jurisdiction before using this for official tax invoices. Receipt printing, barcode scanning, OCR for scanned invoices, bulk import, and staff accounts are not included in this first version.
