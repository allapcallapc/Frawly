import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import worker, { type Env } from '../src/worker.js';

/// Integration test for the actual deployed entrypoint (src/worker.ts),
/// not just the client/tools logic underneath it: a real MCP Client, using
/// the real StreamableHTTPClientTransport, with its `fetch` option pointed
/// directly at worker.fetch() in-process (no real network call, no
/// Miniflare needed - the worker only uses Web-standard APIs). This
/// exercises the HTTP-level bits client.test.ts/tools.test.ts don't:
/// the Authorization header gate, path routing (/health, /mcp, 404s), and
/// the real Streamable HTTP request/response framing.

const env: Env = { BACKEND_URL: 'https://frawly-api.example.com' };

function workerFetch(passphrase?: string): typeof fetch {
  return (async (input: string | URL | Request, init?: RequestInit) => {
    const request = new Request(input, init);
    if (passphrase && !request.headers.has('Authorization')) {
      request.headers.set('Authorization', `Bearer ${passphrase}`);
    }
    return worker.fetch(request, env);
  }) as unknown as typeof fetch;
}

describe('Frawly MCP Worker', () => {
  it('GET /health returns ok without authentication', async () => {
    const response = await worker.fetch(new Request('https://mcp.example.com/health'), env);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true });
  });

  it('404s on any path other than /health and /mcp', async () => {
    const response = await worker.fetch(new Request('https://mcp.example.com/other'), env);
    expect(response.status).toBe(404);
  });

  it('rejects /mcp with no Authorization header', async () => {
    const response = await worker.fetch(
      new Request('https://mcp.example.com/mcp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream' },
        body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'ping' }),
      }),
      env,
    );
    expect(response.status).toBe(401);
  });

  describe('via a real MCP Client', () => {
    let client: Client;
    let backendFetch: ReturnType<typeof vi.fn>;

    beforeEach(async () => {
      backendFetch = vi.fn(async (url: string | URL) => {
        const path = new URL(String(url)).pathname;
        if (path === '/containers/registry') {
          return new Response(JSON.stringify([{ id: 'P-1', date: null, status: 'vacant', ingredients: [] }]), {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          });
        }
        return new Response('not found', { status: 404 });
      });
      vi.stubGlobal('fetch', backendFetch);

      const transport = new StreamableHTTPClientTransport(new URL('https://mcp.example.com/mcp'), {
        fetch: workerFetch('letmein'),
      });
      client = new Client({ name: 'test-client', version: '0.0.0' });
      await client.connect(transport);
    });

    afterEach(() => {
      vi.unstubAllGlobals();
    });

    it('lists tools through the real HTTP transport', async () => {
      const { tools } = await client.listTools();
      expect(tools.map((t) => t.name)).toContain('list_registry');
    });

    it('forwards the Authorization header through to the backend as the passphrase', async () => {
      const result = await client.callTool({ name: 'list_registry', arguments: {} });
      expect(result.isError).toBeFalsy();
      const [, init] = backendFetch.mock.calls[0] as [string, RequestInit];
      expect((init.headers as Record<string, string>).Authorization).toBe('Bearer letmein');
    });
  });
});
