import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { WebStandardStreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/webStandardStreamableHttp.js';

import { FrawlyClient } from './client.js';
import { registerFrawlyTools } from './tools.js';

export interface Env {
  /** The Frawly backend this environment's MCP tools should talk to - see wrangler.toml. */
  BACKEND_URL: string;
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

    const client = new FrawlyClient({ backendUrl: env.BACKEND_URL, passphrase });
    const server = new McpServer({ name: 'frawly-mcp-server', version: '0.1.0' });
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
