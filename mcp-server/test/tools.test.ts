import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';
import { beforeEach, describe, expect, it } from 'vitest';

import { FrawlyClient } from '../src/client.js';
import { registerFrawlyTools } from '../src/tools.js';

/// End-to-end tool tests: a real MCP Client and Server talking over an
/// in-memory transport pair (same wiring stdio would give a real MCP host),
/// with only the HTTP layer (fetch) faked - this exercises the actual
/// tools/call JSON-RPC round trip, zod input validation included, not just
/// the handler functions in isolation.

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

async function textOf(result: Awaited<ReturnType<Client['callTool']>>): Promise<unknown> {
  const content = result.content as Array<{ type: string; text: string }>;
  expect(content[0].type).toBe('text');
  return JSON.parse(content[0].text);
}

describe('Frawly MCP tools', () => {
  let client: Client;
  let fetchCalls: Array<{ url: string; init?: RequestInit }>;

  beforeEach(async () => {
    fetchCalls = [];
    const fetchImpl = (async (url: string | URL, init?: RequestInit) => {
      fetchCalls.push({ url: String(url), init });
      const path = new URL(String(url)).pathname;
      const method = init?.method ?? 'GET';

      if (path === '/containers/registry') {
        return jsonResponse([{ id: 'P-1', date: null, status: 'vacant', ingredients: [] }]);
      }
      if (path === '/containers' && method === 'GET') {
        return jsonResponse([{ id: 'P-1', date: null, status: 'vacant', ingredients: [] }]);
      }
      if (path === '/containers/P-1' && method === 'GET') {
        return jsonResponse({ id: 'P-1', date: null, status: 'vacant', ingredients: [] });
      }
      if (path === '/containers/P-9' && method === 'GET') {
        return new Response('not found', { status: 404 });
      }
      if (path === '/containers' && method === 'POST') {
        const requestedId = JSON.parse((init?.body as string) ?? '{}').id as string;
        if (requestedId === 'P-1') {
          return jsonResponse({ error: 'Container id "P-1" already exists.' }, 409);
        }
        return jsonResponse({ id: requestedId }, 201);
      }
      if (path === '/containers/range') {
        return jsonResponse({ added: ['P-1', 'P-2'] });
      }
      if (path === '/containers/P-1' && method === 'DELETE') {
        return new Response(null, { status: 204 });
      }
      if (path === '/containers/empty') {
        return jsonResponse({ emptied: ['P-1'] });
      }
      if (path === '/containers/P-1' && method === 'PATCH') {
        return jsonResponse({ id: 'P-1', date: '2026-01-01', status: 'frozen', ingredients: [] });
      }
      if (path === '/fillings') {
        return jsonResponse({ updated: ['P-1', 'P-2'] });
      }
      if (path === '/export') {
        return jsonResponse({ version: 1, exportedAt: '2026-01-01T00:00:00.000Z', containers: [] });
      }
      throw new Error(`Unhandled request in test fetch stub: ${method} ${path}`);
    }) as unknown as typeof fetch;

    const frawlyClient = new FrawlyClient({
      backendUrl: 'https://frawly-api.example.com',
      passphrase: 'letmein',
      fetchImpl,
    });

    const server = new McpServer({ name: 'frawly-mcp-server-test', version: '0.0.0' });
    registerFrawlyTools(server, frawlyClient);

    const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
    client = new Client({ name: 'test-client', version: '0.0.0' });
    await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  });

  it('lists every registered tool', async () => {
    const { tools } = await client.listTools();
    const names = tools.map((t) => t.name).sort();
    expect(names).toEqual(
      [
        'add_container',
        'add_container_range',
        'create_filling',
        'empty_containers',
        'export_data',
        'get_container',
        'list_containers',
        'list_registry',
        'remove_container',
        'update_container',
      ].sort(),
    );
  });

  it('list_registry returns the parsed registry', async () => {
    const result = await client.callTool({ name: 'list_registry', arguments: {} });
    expect(await textOf(result)).toEqual([{ id: 'P-1', date: null, status: 'vacant', ingredients: [] }]);
  });

  it('list_containers forwards status/search filters', async () => {
    await client.callTool({ name: 'list_containers', arguments: { status: 'vacant', search: 'P' } });
    const url = new URL(fetchCalls.at(-1)!.url);
    expect(url.searchParams.get('status')).toBe('vacant');
    expect(url.searchParams.get('search')).toBe('P');
  });

  it('get_container returns null for an unregistered id', async () => {
    const result = await client.callTool({ name: 'get_container', arguments: { id: 'P-9' } });
    expect(await textOf(result)).toBeNull();
  });

  it('add_container_range returns the added ids', async () => {
    const result = await client.callTool({
      name: 'add_container_range',
      arguments: { prefix: 'P', from: 1, to: 2 },
    });
    expect(await textOf(result)).toEqual({ added: ['P-1', 'P-2'] });
  });

  it('remove_container sends a DELETE and confirms removal', async () => {
    const result = await client.callTool({ name: 'remove_container', arguments: { id: 'P-1' } });
    expect(await textOf(result)).toEqual({ removed: 'P-1' });
    expect(fetchCalls.at(-1)!.init?.method).toBe('DELETE');
  });

  it('update_container rejects a malformed date via input schema validation', async () => {
    const result = await client.callTool({
      name: 'update_container',
      arguments: { id: 'P-1', date: 'not-a-date', status: 'frozen', ingredients: [] },
    });
    expect(result.isError).toBe(true);
  });

  it('create_filling atomically fills multiple targets', async () => {
    const result = await client.callTool({
      name: 'create_filling',
      arguments: {
        targetIds: ['P-1', 'P-2'],
        date: '2026-01-01',
        status: 'frozen',
        ingredients: [{ name: 'Chili', quantity: '500g' }],
      },
    });
    expect(await textOf(result)).toEqual({ updated: ['P-1', 'P-2'] });
  });

  it('export_data returns the full document', async () => {
    const result = await client.callTool({ name: 'export_data', arguments: {} });
    expect(await textOf(result)).toMatchObject({ version: 1, containers: [] });
  });

  it('surfaces a backend error (e.g. a 409 conflict) as an MCP tool error, not a thrown exception', async () => {
    const result = await client.callTool({ name: 'add_container', arguments: { id: 'P-1' } });
    expect(result.isError).toBe(true);
    const content = result.content as Array<{ type: string; text: string }>;
    expect(content[0].text).toContain('already exists');
  });

  it('add_container succeeds for a new id', async () => {
    const result = await client.callTool({ name: 'add_container', arguments: { id: 'P-2' } });
    expect(result.isError).toBeFalsy();
    expect(await textOf(result)).toEqual({ id: 'P-2' });
  });
});
