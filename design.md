# Om Sri Laxmi Traders — Interface Design

This guide describes the current visual system for the Store Desk. UI markup and interactions live in `src/app.js`; styling lives in `styles.css`.

## Design direction

- **Character:** contemporary merchant workspace: confident, precise, calm, and practical at a busy counter.
- **Color language:** deep ink-blue navigation, cool white and mist-gray surfaces, and a focused teal accent. Avoid terracotta, beige, and decorative gradients as the primary brand language.
- **Hierarchy:** strong page titles, short supporting copy, readable financial figures, and compact metadata. Keep a page focused on its task.
- **Typography:** DM Sans for interface copy and controls; Manrope for headings and prominent figures. Use tabular numerals for quantities and money.
- **Icons:** consistent outline icons with labels for navigation and actions.

## Color tokens

| Token | Value | Use |
| --- | --- | --- |
| `--navy` | `#142b3a` | Main sidebar and navigation shell |
| `--ink` | `#172733` | Primary text |
| `--muted` | `#687985` | Supporting text |
| `--canvas` | `#f3f6f7` | Page background |
| `--paper` | `#ffffff` | Cards, dialogs, tables |
| `--line` | `#dfe7eb` | Borders and separators |
| `--accent` | `#087f78` | Primary actions and selected states |
| `--accent-dark` | `#06645f` | Hover and pressed states |
| `--green` | `#21805d` | Successful or healthy status |
| `--red` | `#b74648` | Errors, mismatches, destructive actions |
| `--blue` | `#426b91` | Informational status |
| `--violet` | `#6e6595` | Secondary analytics |

Use color with consistent meaning. Teal marks the main action and active location; green indicates success; amber indicates a caution; red indicates an error or mismatch.

## App shell and navigation

- **Desktop:** fixed ink-blue sidebar, white header, centered content area, and quiet footer. Keep all eight workspace destinations visible in the sidebar.
- **Mobile:** use a five-item bottom bar for Overview, Bills, Invoices, Stock, and Parties. The store mark button opens a full-height sidebar drawer with all destinations, database status, and sign-out.
- **Header:** the store mark toggles the side navigation; the header identifies the store and shows the date without repeating the page name.
- **Footer:** use only “Built for Om Sri Laxmi Traders”.
- **Content:** use a responsive maximum width. Do not let the page itself scroll horizontally; dense data tables may scroll within their own container.

## Page patterns

### Overview

Show four summary measures followed by fast paths for starting a wholesale bill, reviewing a vendor PDF, and checking inventory. Recent transactions and stock watch sit below. Keep figures prominent and supporting labels quiet. Empty states should explain what will appear and provide the next useful action.

### New bill

The wholesale flow searches registered customers, captures the customer’s MRP discount, searches inventory products, and asks for quantity in a dialog. Preserve purchase-date and stock context in product results and the quantity dialog. Keep invoice columns in the requested order and the tax, total, payment, and early-payment savings clear. Never use quantity steppers.

### Purchase bills

Keep PDF selection and extraction steps clear, show extraction progress in context, and present the extracted bill as an editable review. Display validation status on the affected row and summary. Mismatches use a light red surface; successful checks use a light green surface. A confirmation dialog explains any mismatch before proceeding.

### Invoices and ledgers

Invoices remain available from their dedicated list and customer ledgers. Editing an invoice must continue to update the invoice, inventory, and customer balance together.

### Inventory and customers

Use readable, compact tables with tabular money and quantities. Preserve the required product details and searchable customer balances. Avoid adding decorative columns that obscure the operational fields.

### Settings

Separate connection preferences, store preferences, and saved AI model profiles into clearly titled sections. Mask credentials and make the active model easy to recognize.

## Components

- **Primary button:** teal fill, white label, medium radius, clear hover and keyboard-focus states.
- **Secondary button:** white or pale blue-gray with a fine border.
- **Panels:** white surface, cool hairline border, restrained shadow, and 12–16px radius.
- **Forms:** labels above controls, 42px minimum control height, visible teal focus ring, and no number-input steppers.
- **Dialogs:** fit the viewport with safe margins; keep primary actions visible; stack actions on narrow screens.
- **Status:** use both text/icon and color so state does not rely on color alone.
- **Toasts:** concise messages with neutral, success, or error backgrounds.

## Responsive behavior

- Around `1100px`, reduce page gutters and card spacing.
- At `780px`, switch to the bottom navigation and drawer, stack primary work areas, and keep search and page headings from overflowing.
- At `560px`, use one-column forms, compact metric cards, and dialogs sized to the viewport.
- Dense invoice tables may scroll inside their own wrapper. Mobile table cards should retain clear field labels.
- Respect safe-area insets on mobile devices.

## Print invoices

Wholesale invoices print on A5 portrait paper with compact typography, narrow margins, legible totals, and optional discount percentage. Keep early-payment due date and savings terms easy to find.

## Implementation notes

- Adjust colors, spacing, typography, and responsive components in `styles.css`.
- Adjust page structure and interactions in `src/app.js`.
- Update this document whenever the visual language changes.
- Keep business calculations, Supabase persistence, validation, stock updates, and customer-ledger behavior intact during UI work.


## Settings, expenses and reporting

Settings is a card index that opens separate detail pages for AI models, existing stock entry, and the store connection. Currency and tax controls are omitted. Existing stock entry collects article number, colour, size, MRP, quantity, and unit; Rate is 60% of MRP, Rate below MRP is 40%, cost price is Rate × 95% × 105%, and dealer discount is calculated as (MRP − cost price) ÷ MRP × 100. Per-unit GST is calculated as Rate × 95% × 5% and stored on the product. Expenses are filtered by month and year, with the selected month total shown above the expense list. Data & Graphs compares monthly expenses, wholesale sales, and retail sales over the latest 12 months.


## Dialog standard

All dialogs use the native `<dialog class="modal ...">` shell with `.modal-card` content. Shared sizing caps dialog width at 560px and constrains height to the viewport; content may scroll vertically inside the dialog when the screen is short. Inputs and actions stay within the card, two-column fields collapse on narrow screens, and action buttons wrap without causing horizontal overflow. New dialogs must use this shared class pattern rather than bespoke viewport sizing.


## Minimal panel headings

Application boxes omit advisory copy and empty-state instructions while retaining headings, labels, formulas, status, and actual record data. Quick action and Settings shortcut cards keep only their names and actions. Keep essential counts and status in dedicated controls or content rather than adding helper copy under every panel title.


## Responsive tables

Tables preserve their row and column structure at phone widths and scroll horizontally inside their wrapper, with a visible bottom scrollbar and touch swiping. Set concise per-table column widths for billing, inventory, and purchase review; right-align numeric values and avoid large fixed widths where content permits.


## Wholesale billing customer and payment terms

The bill builder places registered customer search and customer GSTIN, address, and contact details above the invoice card. The early-payment checkbox follows the invoice discount-print checkbox and opens a dialog to collect extra discount and allowed payment days. The savings notice spans the bill above Complete bill and is mirrored on the printed A5 invoice.
