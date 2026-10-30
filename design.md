# Om Sri Laxmi Traders — UI Design Guide

This file describes the current visual language and layout of the Store Desk app. Use it as the reference when changing the interface. Product and billing behavior lives mainly in `src/app.js`; visual rules live in `styles.css`.

## Design direction

- **Feel:** warm, calm, clear, and businesslike; avoid a generic blue dashboard look.
- **Surface:** soft ivory page background, white content panels, fine warm-gray borders, modest shadows, rounded corners.
- **Accent:** terracotta for primary actions and active navigation. Green communicates successful or healthy states; red is reserved for errors and destructive actions.
- **Density:** compact enough for a working shop counter, with readable labels and larger headings. Avoid oversized decoration and unnecessary cards around individual values.
- **Typography:** DM Sans for interface copy and controls; Manrope for headings and prominent figures.
- **Icons:** simple outline icons, consistent stroke weight, used with text labels.

## Design tokens

The main tokens are declared on `:root` in `styles.css`.

| Token | Current value | Use |
| --- | --- | --- |
| `--ink` | `#292821` | Main text |
| `--muted` | `#85837a` | Supporting text |
| `--line` | `#eeece6` | Borders and separators |
| `--paper` | `#fff` | Panels and dialogs |
| `--accent` | `#bd5e37` | Main buttons and highlights |
| `--accent-dark` | `#a84e2b` | Hover state for main buttons |
| `--cream` | `#f4f0e8` | Secondary warm surfaces |
| `--green` | `#327553` | Positive status |
| `--red` | `#b14437` | Error or destructive status |
| `--blue` | `#426999` | Informational status |
| `--violet` | `#745b92` | Secondary statistic tone |

Keep status colors consistent: green means okay, red means action is needed, and terracotta marks a primary action.

## App shell and navigation

- **Desktop:** fixed left sidebar, top header, centered page content, and a small footer. The sidebar includes Overview, New bill, Invoices, Purchase bills, Inventory, Customers, Transactions, and Settings.
- **Tablet:** sidebar narrows before switching to the compact navigation layout.
- **Mobile:** navigation sits along the bottom in a two-row, four-column grid. The main content reserves space above it and accounts for device safe areas.
- **Header:** store identity, current page, date, connection status, and a New bill shortcut.
- **Content width:** capped to keep tables and forms from stretching too far on wide screens.

## Page layouts

### Overview

Four compact summary cards sit above a recent-activity table and a stock-watch panel. Empty states should explain what action will create the first records and provide a direct action button.

### New bill

- Search for a registered customer, then enter the customer’s MRP discount.
- Product search is enabled after the customer and discount are entered.
- Search results show purchase date at lower left and stock at lower right.
- Selecting a product opens a quantity dialog. The dialog shows on-hand stock, bill discount, dealer discount, purchase date, quantity, and the item’s MRP discount.
- The invoice table columns are Item, MRP, Quantity, Price, 5% GST, Price (Incl. Tax), and Total. Quantity is plain text that opens the quantity dialog when tapped.
- The bill supports an optional plus discount for early payment, payment received now, and a checkbox for printing discount percentages.
- Keep totals easy to scan. The payment field is required before completing a bill.

### Invoices and customer ledger

- Invoices have a dedicated sidebar page with search and an edit action.
- A customer’s invoice count opens their invoice list and edit actions.
- Invoice editing shows quantities, per-item MRP discounts, dealer discount references, payment, and early-payment terms.
- Saved changes update inventory and the customer balance together.

### Purchase bills

The upload and extraction area is separate from the extracted invoice review. The review uses a wide, horizontally scrollable table because it represents vendor invoice lines and checks. Summary fields stack in rows; mismatches use a soft red treatment and matching values use a soft green treatment.

### Inventory and customers

Inventory is a data table with description, stock, MRP, rate, rate below MRP, cost price, dealer discount, and stock adjustment. Do not reintroduce SKU. Customer search and account balance remain visible, with invoice access in the bills column.

## Components and interaction rules

- **Primary button:** terracotta fill, white label, medium weight, modest radius. Use for the page’s main action.
- **Secondary button:** warm-gray fill and thin border. Use for cancel, back, and less frequent actions.
- **Panels:** white background, thin warm border, about 11–13px corner radius. Panel headings align left and use a subtle divider.
- **Tables:** small uppercase headers, clear row separators, tabular number alignment for currency, and horizontal scrolling only when the data genuinely needs more width.
- **Dialogs:** fit within the viewport, use a clear title and supporting details, and keep actions visible. Avoid horizontal overflow. On phones, stack action buttons and keep dialogs within the device height.
- **Forms:** labels above inputs, clear focus rings, numeric keyboard hints for prices and quantities, and no increment/decrement steppers.
- **Search suggestions:** white floating surface with a light border and shadow. Keep the product/customer name prominent and supporting information smaller.
- **Toasts:** concise status messages; use red for errors and a neutral/green treatment for success.
- **Empty states:** state what is empty and how the user can add the first record.

## Responsive behavior

The stylesheet uses breakpoints around `1000px`, `780px`, and `560px`.

- At about `1000px`, reduce sidebar and page gutters and collapse dashboard columns.
- At about `780px`, switch navigation to the bottom bar and stack the primary content layouts.
- At about `560px`, use single-column forms and smaller page gutters. Keep important controls full width where practical.
- Tables with many business columns may scroll horizontally inside their own container; the page itself should not gain horizontal overflow.
- Dialogs should use viewport-relative width and height, include safe outer margins, and avoid controls being pushed off screen.

## Invoice print design

Invoice printing uses an A5 portrait page. Keep the type compact and legible, use narrow margins, and avoid large decorative headings. The printed discount column appears only when the user checks the print-discount option. If plus discount is enabled, show the due date and the extra savings amount clearly as a short payment term.

## Where to change the UI

- `styles.css`: colors, type, spacing, panels, tables, dialogs, navigation, and responsive layouts.
- `src/app.js`: page markup, sidebar labels, form fields, dialogs, invoice print markup, and interaction behavior.
- `index.html`: document title, font loading, and stylesheet/script entry points.

When making a visual change, preserve keyboard focus visibility, readable contrast, touch-friendly controls, the no-stepper rule, and stock/payment validation. Keep data changes and visual-only changes distinct so the billing calculations stay consistent with the Supabase functions.
