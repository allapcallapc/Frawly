import { describe, expect, it, vi } from 'vitest';

import { FrawlyApiError, FrawlyClient } from '../src/client.js';

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

function clientWith(fetchImpl: typeof fetch): FrawlyClient {
  return new FrawlyClient({ backendUrl: 'https://frawly-api.example.com', passphrase: 'letmein', fetchImpl });
}

describe('FrawlyClient', () => {
  it('sends the passphrase as a bearer token', async () => {
    const fetchImpl = vi.fn(async (_url: string | URL, init?: RequestInit) => {
      expect((init?.headers as Record<string, string>).Authorization).toBe('Bearer letmein');
      return jsonResponse([]);
    });
    await clientWith(fetchImpl as unknown as typeof fetch).getRegistry();
    expect(fetchImpl).toHaveBeenCalledOnce();
  });

  it('getRegistry parses the returned rows', async () => {
    const row = { id: 'P-1', date: null, status: 'vacant', ingredients: [] };
    const fetchImpl = vi.fn(async () => jsonResponse([row]));
    const result = await clientWith(fetchImpl as unknown as typeof fetch).getRegistry();
    expect(result).toEqual([row]);
  });

  it('listContainers sends status/search as query params', async () => {
    const fetchImpl = vi.fn(async (url: string | URL) => {
      const parsed = new URL(url as string);
      expect(parsed.pathname).toBe('/containers');
      expect(parsed.searchParams.get('status')).toBe('frozen');
      expect(parsed.searchParams.get('search')).toBe('chili');
      return jsonResponse([]);
    });
    await clientWith(fetchImpl as unknown as typeof fetch).listContainers({ status: 'frozen', search: 'chili' });
    expect(fetchImpl).toHaveBeenCalledOnce();
  });

  it('getContainer returns null on 404', async () => {
    const fetchImpl = vi.fn(async () => new Response('not found', { status: 404 }));
    const result = await clientWith(fetchImpl as unknown as typeof fetch).getContainer('P-1');
    expect(result).toBeNull();
  });

  it('addContainer throws FrawlyApiError with the server message on conflict', async () => {
    const fetchImpl = vi.fn(
      async () => jsonResponse({ error: 'Container id "P-1" already exists.' }, 409),
    );
    await expect(clientWith(fetchImpl as unknown as typeof fetch).addContainer('P-1')).rejects.toMatchObject({
      message: 'Container id "P-1" already exists.',
      status: 409,
    });
  });

  it('addContainerRange returns the added ids', async () => {
    const fetchImpl = vi.fn(async () => jsonResponse({ added: ['P-1', 'P-2'] }));
    const result = await clientWith(fetchImpl as unknown as typeof fetch).addContainerRange({
      prefix: 'P',
      from: 1,
      to: 2,
    });
    expect(result).toEqual(['P-1', 'P-2']);
  });

  it('removeContainer succeeds on 204', async () => {
    const fetchImpl = vi.fn(async () => new Response(null, { status: 204 }));
    await expect(clientWith(fetchImpl as unknown as typeof fetch).removeContainer('P-1')).resolves.toBeUndefined();
  });

  it('emptyContainers returns the emptied ids', async () => {
    const fetchImpl = vi.fn(async () => jsonResponse({ emptied: ['P-1'] }));
    const result = await clientWith(fetchImpl as unknown as typeof fetch).emptyContainers(['P-1']);
    expect(result).toEqual(['P-1']);
  });

  it('updateContainer sends the fields and returns the updated container', async () => {
    const updated = { id: 'P-1', date: '2026-01-01', status: 'frozen', ingredients: [] };
    const fetchImpl = vi.fn(async (_url: string | URL, init?: RequestInit) => {
      expect(init?.method).toBe('PATCH');
      expect(JSON.parse(init!.body as string)).toEqual({
        date: '2026-01-01',
        status: 'frozen',
        ingredients: [],
      });
      return jsonResponse(updated);
    });
    const result = await clientWith(fetchImpl as unknown as typeof fetch).updateContainer('P-1', {
      date: '2026-01-01',
      status: 'frozen',
      ingredients: [],
    });
    expect(result).toEqual(updated);
  });

  it('createFilling throws on a 404 with missing ids', async () => {
    const fetchImpl = vi.fn(
      async () => jsonResponse({ error: 'Container id(s) not in the registry.', missing: ['P-9'] }, 404),
    );
    await expect(
      clientWith(fetchImpl as unknown as typeof fetch).createFilling({
        targetIds: ['P-9'],
        date: null,
        status: 'vacant',
        ingredients: [],
      }),
    ).rejects.toBeInstanceOf(FrawlyApiError);
  });

  it('exportAll returns the export document', async () => {
    const doc = { version: 1, exportedAt: '2026-01-01T00:00:00.000Z', containers: [] };
    const fetchImpl = vi.fn(async () => jsonResponse(doc));
    const result = await clientWith(fetchImpl as unknown as typeof fetch).exportAll();
    expect(result).toEqual(doc);
  });

  it('health returns true only on a 200 response', async () => {
    const ok = vi.fn(async () => new Response('{"ok":true}', { status: 200 }));
    expect(await clientWith(ok as unknown as typeof fetch).health()).toBe(true);

    const unauthorized = vi.fn(async () => new Response('', { status: 401 }));
    expect(await clientWith(unauthorized as unknown as typeof fetch).health()).toBe(false);

    const networkError = vi.fn(async () => {
      throw new Error('network down');
    });
    expect(await clientWith(networkError as unknown as typeof fetch).health()).toBe(false);
  });
});
