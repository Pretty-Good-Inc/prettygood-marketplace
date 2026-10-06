# Bonafide plugin

Lets Claude operate wineries on the Bonafide (PrettyGood) platform. It can look up and change orders, fulfillment orders, shipments and tracking, customers, wine club memberships and products, and run data imports.

## What's inside

| Component | Purpose |
|---|---|
| `.mcp.json` | Connects to the Bonafide MCP server at `https://mcp.withbonafide.com/mcp` |
| `skills/bonafide/SKILL.md` | How Claude should use the server: pick the organization, search for the operation, read, and run writes as preflight then execute |

## Connecting

The server uses OAuth. The first time Claude uses it, you're asked to sign in with your Bonafide account. Claude can only see the organizations, and do the operations, that your account is allowed to.

## Safety

- Every change runs as a preview (preflight) first. Claude shows you what will happen and waits for your go-ahead before executing.
- Changes that send email, move money, or permanently delete data also ask for your approval in the app.
- If a change's outcome is unclear, Claude checks its receipt rather than running it again.
