# PrettyGood plugins for Claude

PrettyGood's private plugin marketplace for Claude (claude.ai chat, Cowork and Claude Code).

| Plugin | What it does | Status |
|---|---|---|
| [`bonafide`](plugins/bonafide) | Operate wineries on the Bonafide (PrettyGood) platform through its MCP server | Pilot |
| [`winedirect`](plugins/winedirect) | WineDirect Fulfillment (WD-FS) orders, shipments, inventory and transfers through the PrettyGood WineDirect MCP server | Pilot |

## Install

**claude.ai (Team or Enterprise):** an Owner adds this repository under **Organization settings → Plugins & skills → Add → Sync from GitHub**, then sets each plugin's availability. Members find the plugins under **Customize → Plugins**. Organization sync reads the default branch through the Claude GitHub App, so members don't need access to this repository.

**Claude Code:**

```bash
claude plugin marketplace add Pretty-Good-Inc/prettygood-marketplace
claude plugin install bonafide@prettygood-marketplace
```

For a private repository, this uses the Git credentials already on the machine.

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
3. Merge to `main`. Organization sync releases on pushes to the default branch and ignores tags, so **every merge to `main` is a release**.

## Rules organization sync enforces

- This repository must stay **private or internal** on github.com.
- Plugin sources are relative paths starting with `./` (or `github`, `url`, `git-subdir` sources).
- No top-level `bin/` directory inside a plugin; put executables in `scripts/`.
- Local (stdio) MCP servers don't run in claude.ai chat. Use remote (HTTP) servers.

## Adding a plugin

Copy `plugins/bonafide` as a starting point, add an entry to `.claude-plugin/marketplace.json` with the same `name` as the new `plugin.json`, and open a PR.
