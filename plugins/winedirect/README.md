# WineDirect plugin

Lets Claude work with the WineDirect Fulfillment (WD-FS) 3PL through PrettyGood's WineDirect MCP server. It can look up orders, shipments and tracking, sellable and owned inventory, products, transfers, inbound inventory and invoices. On connections that allow changes, it can also submit, update and cancel orders, save products and create transfers.

## What's inside

| Component | Purpose |
|---|---|
| `.mcp.json` | Connects to the WineDirect MCP server at `https://winedirect-mcp.withbonafide.com/mcp` |
| `skills/winedirect/SKILL.md` | How Claude should use the server: pick the account or supplier, read with summaries and paging, respect WineDirect's quirks, and confirm every change first |

Server source and deploy pipeline: [`Pretty-Good-Inc/winedirect-mcp`](https://github.com/Pretty-Good-Inc/winedirect-mcp).

## Connecting

The server uses OAuth. The first time Claude uses it, you sign in on the server's own page with your **WineDirect API login** (a REST API user, not your Portal login), choose the WineDirect environment, and choose whether to allow changes. Your WineDirect password goes to the server, never to Claude, and is stored encrypted.

One connection covers every account and supplier the WineDirect login can reach. Claude picks the account on each call.

## Safety

- Connections are **read-only unless you tick "Allow changes"** when signing in. Write tools don't exist on a read-only connection.
- Claude confirms the exact change with you before any write.
- Order submission and bulk updates are asynchronous on WineDirect's side, and submission has no duplicate protection, so Claude checks for existing orders before resubmitting.
