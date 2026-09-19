# Frawly MCP server

An [MCP](https://modelcontextprotocol.io) server that exposes the Frawly
backend (see `../backend/README.md`) as tools for an LLM client (Claude
Desktop, Claude Code, etc.) - "list the vacant containers", "fill P-3
through P-6 with the chili I made today", and so on.

Like the Flutter app, this only ever speaks HTTP to the Worker
(`src/client.ts` mirrors `../lib/services/container_service.dart`) - it has
no direct D1/Cloudflare access and no separate credentials. `importAll`
(the full-registry replace `POST /import` uses) is deliberately not
exposed as a tool: it wipes every container, which is more destructive
than seems reasonable to hand an LLM client by default.

## Setup

```
cd mcp-server
pnpm install
pnpm run build
```

Add it to your MCP client's config, pointing `FRAWLY_BACKEND_URL` /
`FRAWLY_PASSPHRASE` at the same backend + passphrase you'd enter on the
app's connect screen. For Claude Code / Claude Desktop
(`claude_desktop_config.json` or `.mcp.json`):

```json
{
  "mcpServers": {
    "frawly": {
      "command": "node",
      "args": ["/absolute/path/to/Frawly/mcp-server/dist/index.js"],
      "env": {
        "FRAWLY_BACKEND_URL": "https://frawly-api-staging.<your-subdomain>.workers.dev",
        "FRAWLY_PASSPHRASE": "<your passphrase>"
      }
    }
  }
}
```

The server checks `GET /health` against these on startup and exits with an
error if the backend isn't reachable - same check the connect screen does.

## Tools

| Tool | Backend route | Notes |
| --- | --- | --- |
| `list_registry` | `GET /containers/registry` | Every container. |
| `list_containers` | `GET /containers` | Optional `status`/`search` filters. |
| `get_container` | `GET /containers/:id` | Null if not registered. |
| `add_container` | `POST /containers` | Fails if the id exists. |
| `add_container_range` | `POST /containers/range` | Existing ids in the range are skipped, not rejected. |
| `remove_container` | `DELETE /containers/:id` | Permanent. |
| `empty_containers` | `POST /containers/empty` | Resets to vacant; doesn't delete. |
| `update_container` | `PATCH /containers/:id` | Overwrites one container. |
| `create_filling` | `POST /fillings` | Atomically fills several containers at once. |
| `export_data` | `GET /export` | Full backup document. |

## Local development

```
pnpm run dev       # runs src/index.ts directly via tsx
pnpm test          # vitest - client.test.ts mocks fetch; tools.test.ts
                    # drives the real MCP Client/Server over an in-memory
                    # transport, so it exercises the actual tools/call
                    # JSON-RPC round trip and zod input validation
pnpm run typecheck
```

To smoke-test against a real backend, run `../backend`'s local dev server
(`cd ../backend && pnpm run dev`) and point `FRAWLY_BACKEND_URL` at
`http://localhost:8787` with `FRAWLY_PASSPHRASE` set to whatever
`../backend/.dev.vars` has.
