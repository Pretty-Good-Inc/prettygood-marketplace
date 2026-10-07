# PrettyGood plugins for Claude

PrettyGood's public plugin marketplace for Claude (claude.ai chat, Cowork and Claude Code), open to every Bonafide customer. The plugins connect to PrettyGood's MCP servers, and each person signs in with their own Bonafide or WineDirect account, so the repository itself holds no secrets.

| Plugin | What it does | Status |
|---|---|---|
| [`bonafide`](plugins/bonafide) | Operate wineries on the Bonafide (PrettyGood) platform through its MCP server | Pilot |
| [`winedirect`](plugins/winedirect) | WineDirect Fulfillment (WD-FS) orders, shipments, inventory and transfers through the PrettyGood WineDirect MCP server | Pilot |

## Install

**Claude Code:**

```bash
claude plugin marketplace add Pretty-Good-Inc/prettygood-marketplace
claude plugin install bonafide@prettygood-marketplace
claude plugin install winedirect@prettygood-marketplace
```

**claude.ai (Team or Enterprise):** organization sync only syncs a marketplace repository that is private or internal, so it can't sync this public repository directly. Instead, an Owner in the customer's organization:

1. Creates a private repository on github.com (for example `your-org/claude-plugins`) with a `.claude-plugin/marketplace.json` that points at the plugins here:

   ```json
   {
     "name": "your-org-plugins",
     "owner": { "name": "Your winery" },
     "plugins": [
       {
         "name": "bonafide",
         "source": { "source": "git-subdir", "url": "https://github.com/Pretty-Good-Inc/prettygood-marketplace.git", "path": "plugins/bonafide" }
       },
       {
         "name": "winedirect",
         "source": { "source": "git-subdir", "url": "https://github.com/Pretty-Good-Inc/prettygood-marketplace.git", "path": "plugins/winedirect" }
       }
     ]
   }
   ```

   Organization sync fetches these public plugin sources without credentials.
2. Adds that repository under **Organization settings → Plugins & skills → Add → Sync from GitHub**, then sets each plugin's availability.

Members then find the plugins under **Customize → Plugins**. Add `"ref"` or `"sha"` to a source to pin a version instead of following `main`.

## Repository layout

```
.claude-plugin/marketplace.json   marketplace catalog
plugins/<name>/                    one folder per plugin
  .claude-plugin/plugin.json       manifest (name must match the catalog entry)
  .mcp.json                        remote MCP server(s) the plugin connects to
  skills/<skill>/SKILL.md          instructions Claude loads when relevant
scripts/check-plugins.sh           organization-sync rule checks (run in CI)
```

MCP server source code doesn't live here. Each server has its own repository and deploy pipeline. A plugin only points at the deployed URL.

## Releasing

1. Change a plugin and bump `version` in its `plugin.json`.
2. Run `claude plugin validate . && bash scripts/check-plugins.sh` locally. CI runs both on every PR.
3. Merge to `main`. Claude Code users get it on their next marketplace update, and customers' claude.ai marketplaces that don't pin a `ref` or `sha` pick it up the next time they sync, so **treat every merge to `main` as a release**.

## Rules to keep

- This repository stays **public**: customers' organization sync fetches its plugin folders without credentials, and Claude Code users add it directly. Never commit secrets or customer data.
- Plugin sources are relative paths starting with `./`, so the same folders work both here and as `git-subdir` sources in customers' marketplaces.
- No top-level `bin/` directory inside a plugin; put executables in `scripts/`.
- Local (stdio) MCP servers don't run in claude.ai chat. Use remote (HTTP) servers.

## Adding a plugin

Copy `plugins/bonafide` as a starting point, add an entry to `.claude-plugin/marketplace.json` with the same `name` as the new `plugin.json`, and open a PR.
