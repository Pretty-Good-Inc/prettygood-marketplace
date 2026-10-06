---
name: bonafide
description: Work in a winery's Bonafide (PrettyGood) admin through the Bonafide MCP tools — look up or change orders, fulfillment orders, shipments and tracking, customers, wine club memberships, products, and data imports. Use whenever the user mentions Bonafide, PrettyGood, withbonafide.com, a winery organization on the platform, or asks about their DTC orders, club members, shipments, or uploading/importing customer, product or order files — even if they don't name the tools.
---

# Bonafide (PrettyGood) platform

The Bonafide MCP server (`https://mcp.withbonafide.com/mcp`) exposes the PrettyGood admin agent API. It doesn't have one tool per endpoint. Instead it has a small set of generic tools and a searchable catalog of operations:

| Tool | Use it to |
|---|---|
| `organization_list` | List the wineries (organizations) this account can operate on, with each one's `slug` and the user's role |
| `capability_search` | Find the operation for a task, described in plain language, within one organization |
| `data_query` | Run a **read** operation |
| `action_execute` | Run a **write** operation, in two phases: `preflight` then `execute` (also `receipt`) |
| `action_receipt` | Find out what happened to an action whose outcome is unclear |

If these tools are missing, the Bonafide connector isn't connected or isn't enabled in this chat. Tell the user to connect it (sign in with their Bonafide account) and stop. Don't fall back to guessing data.

## The loop

1. **Pick the organization.** Call `organization_list` once per conversation and match the user's wording ("Riise", "the Ledge account") to a `slug`. If more than one could match, or the user hasn't said which winery, ask. Never guess an organization for a write. For questions that span wineries, run the steps once per organization and label every result with the winery's name.

2. **Find the operation.** Call `capability_search` with the `organizationSlug` and a short description of the task in the user's terms ("shipments in transit for an order", "a customer's club memberships"). Each candidate includes:
   - `operationId` and `operationRevision`, which you pass to the next call.
   - `kind`: `read` or `write`.
   - In the returned OpenAPI fragment's `x-agent` block: `sideEffects` (`writesData`, `sendsEmail`, `external`), `confirmation`, `pagination`, `failures`, `relatedOperationIds`, and `runbookUris`.

   Pick the candidate whose summary matches the task. If none do, rephrase the query once. If still nothing matches, tell the user the platform doesn't expose that capability to their account. The catalog is filtered by their permissions.

3. **Build the input from the schema, not from memory.** Field names and enums come from the returned schema. Pass only the fields it defines, because unknown fields are rejected.

4. **Reads → `data_query`.**
   - Use `retrieval: {mode: "single_page", cursor: null}` for "show me" questions and spot checks.
   - Use `retrieval: {mode: "all_pages", maxRecords: N}` only when you need a full set (counts, reconciliation, exports). Set `maxRecords` deliberately rather than at the maximum.
   - When a result is truncated it includes `nextCursor`. Say the results are partial, or continue from the cursor.

5. **Writes → `action_execute`, always two phases.**
   - Run `phase: "preflight"` first. Show the user the preflight's presentation of what will change. Call out anything that sends email, moves money, or deletes data.
   - Run `phase: "execute"` with the preflight's confirmation reference and a fresh `idempotencyKey` you generate (e.g. a UUID) **only after the user has said yes** to that specific change.
   - Some changes also require the user's approval inside the host app. That approval can't be supplied in the request, so let the prompt appear and wait.
   - If an execute times out or the result is unclear, call `action_receipt` with the `actionInstanceId` from the preflight. **Never** retry with a new `idempotencyKey`, because that can apply the change twice.

## Errors and what to do

| Code | Do this |
|---|---|
| `READ_INVALID_INPUT` | Fix the payload against the schema and retry the same operation |
| `READ_OPERATION_CHANGED` / `AGENT_OPERATION_CHANGED` | Re-run `capability_search` to get the current revision, then retry |
| `READ_TIMEOUT` | Narrow the query (date range, status filter) and retry |
| `READ_LIMIT_EXCEEDED` | Resume from `nextCursor` or narrow the query |
| `READ_UNAVAILABLE` / `AGENT_GATEWAY_UNAVAILABLE` | Temporary; retry later without searching again |
| `READ_REJECTED` | Search again; if the operation is gone, this account can't do it here |
| `FEATURE_NOT_ENABLED` | The winery has to enable that feature; tell the user |
| `READ_OPERATION_FAILURE` | The operation returned one of its declared `failures`; read `operationFailureCode` and explain it |

Don't loop. After two failed attempts at the same step, stop and tell the user what failed and what you tried.

## Working with the data

- **Money is in cents** (`costCents`, `shippingCostCents`, …). Show dollars to the user.
- **Statuses are enums.** Compare and filter on the enum values (`pre_transit`, `transit`, `delivered`, …), not on display text.
- **Orders vs fulfillment orders vs shipments are different things.** An order is what the customer bought. A fulfillment order is what is sent to be picked and packed. A shipment is one package with one tracking number. One order can have several fulfillment orders, and one fulfillment order can have several packages. When status disagrees between these levels, report each level rather than averaging them.
- **Runbooks.** Candidates list `runbookUris` (e.g. `wine://runbooks/shipping-review`) and `resourceUris`. When the host lets you read MCP resources, read the runbook before multi-step work in that area. It's the platform team's own procedure.
- **Customer data is personal.** Show only the fields the task needs. Don't paste full customer lists into the chat when a count or a few examples will do.
- **Imports are multi-step.** Uploading customer, product or order files starts with `reserveBatch`, followed by uploading each part, then `commitBatch` (or `withdrawBatch`/`cancel`). Search for the import operations and follow the import runbook rather than improvising the order of steps.

## Answering

Lead with the answer: the number, the status, or the list. Then give the winery and the scope it covers ("Riise, shipments created since Oct 1, first 50"). For writes, end with what changed and the action's ID, so the user can look it up later.
