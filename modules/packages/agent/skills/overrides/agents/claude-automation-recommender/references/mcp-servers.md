# MCP Servers for OpenCode

MCP servers extend OpenCode with external tools and services.

## Configuration

Servers live in the `mcp` key of `opencode.json` (or `opencode.jsonc`):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "docs": {
      "type": "remote",
      "url": "https://mcp.example.com/mcp",
      "enabled": true,
    },
    "local-tool": {
      "type": "local",
      "command": ["npx", "-y", "@scope/local-mcp"],
      "environment": { "API_KEY": "${API_KEY}" },
      "timeout": { "startup": 20000 },
    },
  },
}
```

- Local server: `type: "local"` plus `command` as an array of strings.
- Remote server: `type: "remote"` plus a `url`.
- `enabled: false` disables a server without removing it.
- `environment` supplies env vars; `${VAR}` is substituted from the environment.

Inspect what is connected with:

```bash
opencode mcp list
```

Team sharing works by committing `opencode.json` to the repository. Global servers go in `~/.config/opencode/opencode.json`.

## Server catalogue

| Server | Best for | Install |
|--------|----------|---------|
| **context7** | Live documentation for popular libraries | `npx -y @upstash/context7-mcp` |
| **Playwright** | Browser automation and UI testing | `npx -y @playwright/mcp@latest` |
| **Puppeteer** | Headless Chrome control | `npx -y @puppeteer/mcp` |
| **Supabase** | Direct database and storage operations | `npx -y @supabase/mcp-server` |
| **Convex** | Live deployment introspection and queries | `npx -y convex mcp start` |
| **Postgres** | Query and schema work | `npx -y @modelcontextprotocol/server-postgres` |
| **GitHub** | Issues, PRs, actions, releases | `npx -y @modelcontextprotocol/server-github` |
| **Linear** | Issue management | `npx -y @linear/mcp-server` |
| **AWS** | Cloud resource management | `uvx awslabs.aws-api-mcp-server` |
| **Slack** | Team notifications | `npx -y @modelcontextprotocol/server-slack` |
| **Sentry** | Error investigation | `https://mcp.sentry.dev/mcp/{org}/{project}` |
| **Docker** | Container management | `npx -y @modelcontextprotocol/server-docker` |
| **Filesystem** | Sandboxed directory access | `npx -y @modelcontextprotocol/server-filesystem` |
| **Memory** | Cross-session context notes | `npx -y @modelcontextprotocol/server-memory` |

Use the `gh` CLI for GitHub work rather than adding a GitHub MCP server; the CLI is faster and already authenticated in most setups.

## When to recommend each

| Codebase signal | Recommended server |
|-----------------|-------------------|
| Popular libraries in use | context7 — live docs instead of remembered APIs |
| Frontend needing UI verification | Playwright — drive and screenshot the running app |
| Supabase in dependencies | Supabase MCP — query tables and storage directly |
| Convex in dependencies | Convex MCP — introspect tables, function specs, env vars, logs |
| PostgreSQL or MySQL | Database MCP — schema and query tools |
| GitHub repository | GitHub MCP — issues, PRs, workflow runs |
| Linear for issue tracking | Linear MCP |
| AWS infrastructure | AWS MCP |
| Slack workspace | Slack MCP |
| Sentry SDK present | Sentry MCP — issues and root causes |
| Docker Compose setup | Docker MCP — containers and logs |
| Cross-session notes needed | Memory MCP |

## Cost and risk

Every MCP server adds tool schemas to the model context. A handful of well-chosen servers is usually better than a dozen. Each server also runs with the user's own authority: a local server is a process you are trusting with the filesystem and network.

Rules to follow when recommending:

- Only suggest servers the project actually needs.
- Never suggest a server that would transmit repository contents to a third party without the user asking.
- Prefer remote servers with scoped credentials over local servers that need broad filesystem access.
- MCP tool permissions can be gated with the `skill` and `<server>_<tool>` actions in `permissions`.
