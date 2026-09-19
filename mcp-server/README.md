# Frawly MCP server

An [MCP](https://modelcontextprotocol.io) server that exposes the Frawly
backend (see `../backend/README.md`) as tools for an LLM client (Claude
Desktop, Claude Code, etc.) - "list the vacant containers", "fill P-3
through P-6 with the chili I made today", and so on.

It's a Cloudflare Worker, same as `../backend/` - deployed once, reachable
by URL, no local process to keep running. Like the Flutter app, it only
ever speaks HTTP to the backend Worker (`src/client.ts` mirrors
`../lib/services/container_service.dart`) - it has no direct D1/Cloudflare
access of its own. `POST /import` (the full-registry replace) is
deliberately not exposed as a tool: it wipes every container, which is
more destructive than seems reasonable to hand an LLM client by default.

## Auth

There's no separate secret for this Worker. The passphrase you configure
your MCP client with (the same one you'd enter on the app's connect
screen) is forwarded as-is on every backend request this session makes -
the Worker itself never stores or validates it. A wrong passphrase
surfaces as a normal 401 from the backend, turned into an MCP tool error.

## One-time deploy setup

```
cd mcp-server
pnpm install
```

`wrangler.toml` needs one thing per environment: the backend Worker's URL
(not secret, just deployment-specific - see its own comment for why this
one isn't gitignored the way `../backend/wrangler.toml` is).

- **Local dev**: already points at `http://localhost:8787` (`wrangler
  dev`'s default, matching `../backend/README.md`'s local setup).
- **Staging/production**: once `../backend` has been deployed to that
  environment, replace `REPLACE_WITH_STAGING_BACKEND_URL` /
  `REPLACE_WITH_PRODUCTION_BACKEND_URL` in `wrangler.toml` with the real
  `*.workers.dev` URL, then:

  ```
  pnpm run deploy:staging
  pnpm run deploy:production
  ```

  CI (`.github/workflows/mcp-server-deploy.yml`) does this automatically
  instead, from two repo **variables** (not secrets, since the URL isn't
  sensitive) - `MCP_STAGING_BACKEND_URL` / `MCP_PRODUCTION_BACKEND_URL`
  (Settings > Secrets and variables > Actions > Variables) - reusing the
  same `CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_ACCOUNT_ID` repo secrets
  `../backend` already needs.

## Adding it to your MCP client

Once deployed, point your client at `https://<worker-url>/mcp` with the
passphrase as a bearer token. For Claude Code:

```
claude mcp add --transport http frawly https://frawly-mcp-staging.<your-subdomain>.workers.dev/mcp \
  --header "Authorization: Bearer <your passphrase>"
```

For Claude Desktop (`claude_desktop_config.json`) or `.mcp.json`:

```json
{
  "mcpServers": {
    "frawly": {
      "url": "https://frawly-mcp-staging.<your-subdomain>.workers.dev/mcp",
      "headers": { "Authorization": "Bearer <your passphrase>" }
    }
  }
}
```

`GET /health` (no auth needed) is there to sanity-check the deployment
itself is reachable, same check the connect screen and backend both use.

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
pnpm run dev        # wrangler dev on http://localhost:8787 by default (see wrangler.toml)
pnpm test           # vitest - client.test.ts mocks fetch; tools.test.ts drives a
                     # real MCP Client/Server over an in-memory transport; worker.test.ts
                     # drives a real MCP Client + StreamableHTTPClientTransport straight
                     # into the Worker's fetch handler (auth gate, routing, HTTP framing)
pnpm run typecheck
```

`pnpm run dev` starts the *real* Workers runtime (workerd via `wrangler
dev`), not a Node polyfill - worth testing against directly before
deploying, since some runtime behavior only shows up there (e.g.
Cloudflare's `fetch` throws if called detached from `globalThis`, which
Node's `fetch` happily allows - `src/client.ts` binds it explicitly for
exactly this reason). Point it at `../backend`'s own local dev server
(`cd ../backend && pnpm run dev`) running at the default
`http://localhost:8787`.
