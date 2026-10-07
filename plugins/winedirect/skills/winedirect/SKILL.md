---
name: winedirect
description: Work with the WineDirect Fulfillment (WD-FS) 3PL through the WineDirect MCP tools (wd_*) — look up and reconcile orders, holds, shipments and tracking, returns, sellable and owned inventory, inventory activity, products, inter-warehouse transfers, inbound inventory (INs) and invoices, and (on connections that allow changes) submit, update or cancel orders, save products and create transfers. Use whenever the user mentions WineDirect, WD-FS, wd-fs.com, "the fulfillment center", "the 3PL", "the warehouse", Glenwillow, Green Island, Paso Robles, Santa Maria or Willamette Valley, picking/packing/shipping wine, hold-at-location, tracking numbers for wine orders, or reconciling orders between PrettyGood/Bonafide and WineDirect — even if they don't name the tools. Also for quick questions like "what shipped yesterday", "is order X still on hold", or "how much of SKU Y is in Glenwillow".
---

# WineDirect Fulfillment (WD-FS)

The WineDirect MCP server wraps WineDirect's REST API with one tool per task. Every tool name starts with `wd_`.

| Area | Tools |
|---|---|
| Discovery | `wd_list_accounts` (call first), `wd_list_customer_warehouses`, `wd_describe_schema` (offline API spec lookup) |
| Orders | `wd_list_orders`, `wd_get_order`, `wd_list_orders_on_hold` |
| Shipments | `wd_list_shipments`, `wd_get_shipment`, `wd_list_shipment_updates`, `wd_list_returns` |
| Inventory | `wd_get_sellable_inventory`, `wd_get_owned_inventory`, `wd_get_inventory_activity` |
| Products | `wd_list_owned_products`, `wd_list_sellable_products`, `wd_get_product` |
| Transfers | `wd_list_transfers`, `wd_get_transfer`, `wd_list_inventory_ins` |
| Finance | `wd_list_invoices` |
| Writes (only if the connection allows changes) | `wd_submit_orders`, `wd_update_order`, `wd_cancel_order`, `wd_bulk_update_orders`, `wd_save_product`, `wd_create_transfer`, `wd_request` |

If no `wd_*` tools are available, the WineDirect connector isn't connected or isn't enabled in this chat. Tell the user to connect it (they sign in with their WineDirect **API** login) and stop. Don't guess at fulfillment data.

## The loop

1. **Know the environment.** The connection is either **UAT** (WineDirect's test system) or **Production**. `wd_list_accounts` returns `environment`. Mention it when it matters: always before a write, and whenever the user might mistake UAT test data for real data.

2. **Pick the account or supplier.** Call `wd_list_accounts` once per conversation. It returns:
   - `accounts[]`: `accountNumber` and `customerName`. Pass `accountNumber` to order, shipment, return, sellable inventory, sellable product, warehouse and invoice tools.
   - `suppliers[]`: `supplierId`, `vendorName` and `vendorType`. Pass `supplierId` to owned inventory, inventory activity, owned product, product detail, transfer and inbound inventory tools. **`supplierId` is WineDirect's vendor ID, not the account number.** WineDirect calls it "supplierId (aka vendorId)".

   Match the user's wording to a winery. If more than one could match, or the user hasn't said which, ask. Never guess an account for a write. The server rejects accounts the login can't reach and lists the valid ones.

3. **Read with summaries and paging.**
   - List tools return compact summary rows by default. Use the matching `wd_get_*` tool (`wd_get_order`, `wd_get_shipment`, `wd_get_product`, `wd_get_transfer`) for one record's full detail. Pass `view: "full"` only when you need many complete objects at once.
   - List results come back as `{totalItems, offset, returned, nextOffset, columns, items, note}`. In summary view each item is a row of values in `columns` order (`null` means no value). Read rows by column name, and present them to the user as a table or list, not as raw arrays.
   - While `nextOffset` isn't null there is more: call the same tool with the **same filters** and `offset: nextOffset`. Page through everything for counts, reconciliation and exports. For "show me" questions, one page is fine, but say it's partial ("first 100 of 282").
   - Narrow with filters (dates, status, warehouse, SKU, order type) before paging through large sets.

4. **Writes: describe, confirm, then call.** See [Changing data](#changing-data).

## WineDirect quirks to respect

- **Order dates default to the last 30 days.** For "this year", "all" or any older order, set both `searchStartDate` and `searchEndDate` (YYYY-MM-DD). **Closed orders are excluded** unless `includeClosed: true`.
- **Two order numbers.** `orderNumber` is the customer's (upstream) order number, the one PrettyGood/Bonafide sent. `wineDirectOrderNumber` is WineDirect's internal one. `wd_get_order` takes the customer order number.
- **Shipments:** give either a date range or an `orderNumber`, not both. Prefer `wd_list_shipments` over walking orders one by one. `wd_list_shipment_updates` windows are in **Pacific time** and accept `YYYY-MM-DD` or `YYYY-MM-DDTHH:mm`.
- **Sellable inventory with a `sku` ignores every other filter**, including `warehouseCode`. For one SKU across warehouses, pass only `sku` and read the per-warehouse rows.
- **Owned inventory takes `warehouseCode` or `sku`, not both.** WineDirect rejects the combination.
- **Warehouse codes:** GLW Glenwillow, WDI Green Island, PSO Paso Robles, SMA Santa Maria, SHW Willamette Valley. `wd_list_customer_warehouses` shows which ones an account uses.
- **Inventory quantities:** `qtyAvailableToSell` and `qtyAvailableToPromise` are what can still be sold. `qtyOnHand` includes stock already committed to orders (`qtyOnOrders`).
- **Transfers** default to the last 30 days. They are looked up by WineDirect reference number (e.g. `TRAN-1234`).

## Changing data

Write tools exist only when the user ticked "Allow changes" when connecting. If the user asks for a change on a read-only connection, say so: they'd need to reconnect and allow changes.

For every write:

1. **Get the exact shape** with `wd_describe_schema` (e.g. `schema: "OrdersImportRequest"`, `"OrderEditRequest"`, `"CreateWineRequest"`, `"TransferCreateRequest"`). WineDirect's field names are often surprising: `SubmitOrders` uses `customerOrderId` and `shippingPriority`. Build the body from the schema, not from memory.
2. **Show the user the exact change**: environment, account, the records affected and the values. Wait for a yes to that specific change.
3. **Call the tool once.**

Tool-specific rules:

| Tool | Watch out for |
|---|---|
| `wd_submit_orders` | **Asynchronous:** it returns a queue receipt, and orders take up to about 15 minutes to appear in `wd_list_orders`. **No duplicate protection:** before resubmitting, check the orders don't already exist (search by order number and a date range that covers them) |
| `wd_update_order` | **Not a partial update.** Get the order with `wd_get_order`, change it, and send the **full** line-items array back (only the address may be omitted). It fails once the order has shipped |
| `wd_cancel_order` | Only before the cancel window closes. It's a soft delete, so the order still appears in some searches. `renameOrder: true` frees the order number for reuse, which matters if the upstream system will resubmit the same number |
| `wd_bulk_update_orders` | For orders on hold. Get `bulkOrderUpdateId`s from `wd_list_orders_on_hold`. At least one change field is required. Asynchronous: takes several minutes |
| `wd_save_product` | `kind` picks the request type: `wine`, `nonwine`, or `bom` (gift sets, pick-to-order) |
| `wd_request` | Escape hatch for endpoints without a dedicated tool (inventory INs/OUTs, inventory moves, hold-at-carrier, packing slips, SKU rename). Look the endpoint up with `wd_describe_schema` first and prefer a dedicated tool. Confirm any non-GET call with the user |

If a write's outcome is unclear (a timeout, or an asynchronous job), check the result with the read tools before trying again. Never resubmit blindly.

## Errors

| Message says | Do this |
|---|---|
| `accountNumber "…" isn't available to this WineDirect login` (or a supplierId) | Use one of the listed values, or ask the user which winery they meant |
| `WineDirect rejected this request (HTTP 401) for GET …` | That endpoint refused this login, possibly a missing permission. Other tools may still work. If every tool fails this way, the user should disconnect and reconnect the connector |
| `WineDirect rejected this login and password a few minutes ago` | The stored password is wrong or changed. The user reconnects with the current password after 5 minutes |
| HTTP 400 with WineDirect's message | Fix the input using `wd_describe_schema` and WineDirect's message, then retry once |
| `This server no longer allows WineDirect … connections` | The server stopped allowing that WineDirect environment. The user disconnects, reconnects and picks an available one |

Don't loop. After two failed attempts at the same step, stop and tell the user what failed and what you tried.

## Reconciling with PrettyGood / Bonafide

When the Bonafide tools are also connected, match orders on the **customer order number**: Bonafide's order or fulfillment-order number equals WineDirect's `orderNumber`. Compare status at each level (order, hold, shipment, tracking) and report disagreements per order rather than summarizing them away. Page through both sides completely before claiming something is missing.

## Answering

Lead with the answer: the count, the status, the quantity or the list. Then give the scope it covers: environment, account or supplier, date range and filters ("UAT, ACME Winery, orders Jan 1 – Oct 6, open only: 282 total, showing 100"). For writes, end with what changed, WineDirect's receipt or reference, and, for asynchronous calls, when to check back.
