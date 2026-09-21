import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { WebStandardStreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js';
import type { Fetcher } from '@cloudflare/workers-types';

import { FrawlyClient } from './client.js';
import { registerFrawlyTools } from './tools.js';
import { FRAWLY_ICON_DATA_URI } from './icon.generated.js';

export interface Env {
  /** The Frawly backend this environment's MCP tools should talk to - see wrangler.toml. */
  BACKEND_URL: string;
  /**
   * Service binding to the frawly-api Worker (staging/production only -
   * see wrangler.toml). Cloudflare blocks a Worker from fetch()-ing
   * another Worker's bare *.workers.dev URL directly ("error code: 1042"
   * - discovered when every tool call failed with a bare 404 despite
   * BACKEND_URL being correct, confirmed by hitting the same URL from a
   * browser and getting the expected response), so this binding is the
   * real transport there. Local dev has no binding configured - its
   * BACKEND_URL is a plain http://localhost address, which a normal
   * fetch() reaches fine.
   */
  BACKEND?: Fetcher;
}

function extractPassphrase(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token || null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return jsonResponse({ ok: true });
    }
    if (url.pathname !== '/mcp') {
      return jsonResponse({ error: 'Not found. MCP requests go to /mcp.' }, 404);
    }

    // The passphrase is never stored here - it's forwarded from the
    // caller's own Authorization header straight through to every backend
    // request this session makes (see FrawlyClient), the same shared
    // passphrase the app's connect screen uses. A wrong one surfaces as a
    // normal 401 from the backend on the first tool call, not from here.
    const passphrase = extractPassphrase(request);
    if (!passphrase) {
      return jsonResponse({ error: 'Missing Authorization: Bearer <passphrase> header.' }, 401);
    }

    const client = new FrawlyClient({
      backendUrl: env.BACKEND_URL,
      passphrase,
      // Structurally compatible at runtime (Cloudflare's Request/Response
      // are supersets of the standard ones FrawlyClient's type expects) -
      // the mismatch is only in the stricter `cf`-branded workers-types
      // signature, not actual behavior.
      fetchImpl: env.BACKEND
        ? (env.BACKEND.fetch.bind(env.BACKEND) as unknown as typeof fetch)
        : undefined,
    });
    const server = new McpServer({
      name: 'frawly-mcp-server',
      version: '0.1.0',
      // Gives clients like Claude's connector picker an icon instead of a
      // generic placeholder - see scripts/generate-icon.mjs for why this is
      // a generated data URI rather than a hand-maintained one.
      icons: [{ src: FRAWLY_ICON_DATA_URI, mimeType: 'image/png', sizes: ['128x128'] }],
    });
    registerFrawlyTools(server, client);

    // Stateless: a fresh server+transport per request. A serverless Worker
    // has no durable in-memory session store between invocations (and may
    // route consecutive requests to different isolates entirely), so this
    // is the supported pattern for this transport on this kind of runtime
    // - see WebStandardStreamableHTTPServerTransport's own doc comment,
    // which gives a Cloudflare Workers example matching this shape.
    // enableJsonResponse: every tool call here is a quick request/response
    // (no server-initiated progress/streaming to push), so a plain JSON
    // response is simpler and just as spec-compliant as an SSE stream.
    const transport = new WebStandardStreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
      enableJsonResponse: true,
    });
    await server.connect(transport);
    return transport.handleRequest(request);
  },
};
