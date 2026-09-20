import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import type { CallToolResult } from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';

import { FrawlyApiError, type FrawlyClient } from './client.js';

const STATUS_VALUES = ['vacant', 'frozen', 'construction'] as const;

const ingredientSchema = z.object({
  name: z.string().describe('Ingredient name, e.g. "Chili".'),
  quantity: z.string().describe('Free-text quantity, e.g. "500g" or "2 portions".'),
});

const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format.')
  .nullable()
  .describe('The filling date as YYYY-MM-DD, or null if the container is vacant.');

function textResult(data: unknown): CallToolResult {
  return { content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] };
}

function errorResult(error: unknown): CallToolResult {
  const message = error instanceof FrawlyApiError ? `${error.message} (HTTP ${error.status})` : String(error);
  return { content: [{ type: 'text', text: message }], isError: true };
}

/**
 * Registers every Frawly tool on `server`, backed by `client` (a thin REST
 * wrapper around the Cloudflare Worker backend - see client.ts). Mirrors
 * lib/services/container_service.dart's surface, minus `importAll`: a
 * full-registry replace is destructive enough (wipes every container) that
 * it's deliberately left out of the tool surface for now rather than handed
 * to an LLM client by default.
 */
export function registerFrawlyTools(server: McpServer, client: FrawlyClient): void {
  server.registerTool(
    'list_registry',
    {
      title: 'List full registry',
      description:
        'Lists every registered container with its current date/status/ingredients, sorted by prefix then numeric id.',
      annotations: { readOnlyHint: true },
    },
    async (): Promise<CallToolResult> => {
      try {
        return textResult(await client.getRegistry());
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'list_containers',
    {
      title: 'List containers',
      description:
        'Lists containers, optionally filtered by status and/or a text search on id, sorted by date ascending (vacant/null dates first).',
      inputSchema: {
        status: z.enum(STATUS_VALUES).optional().describe('Only include containers with this status.'),
        search: z.string().optional().describe('Only include containers whose id contains this text.'),
      },
      annotations: { readOnlyHint: true },
    },
    async ({ status, search }): Promise<CallToolResult> => {
      try {
        return textResult(await client.listContainers({ status, search }));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'get_container',
    {
      title: 'Get one container',
      description: 'Gets a single container by id. Returns null if the id is not registered.',
      inputSchema: { id: z.string().describe('The container id, e.g. "P-3".') },
      annotations: { readOnlyHint: true },
    },
    async ({ id }): Promise<CallToolResult> => {
      try {
        return textResult(await client.getContainer(id));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'add_container',
    {
      title: 'Add a container',
      description: 'Registers a single new, empty/vacant container id. Fails if the id already exists.',
      inputSchema: { id: z.string().describe('The container id to register, e.g. "P-3".') },
      annotations: { destructiveHint: false },
    },
    async ({ id }): Promise<CallToolResult> => {
      try {
        await client.addContainer(id);
        return textResult({ id });
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'add_container_range',
    {
      title: 'Add a range of containers',
      description:
        'Registers every "<prefix>-<n>" for n in [from, to] that is not already registered - existing ids are skipped, not rejected. Returns the ids actually added.',
      inputSchema: {
        prefix: z.string().describe('The id prefix, e.g. "P".'),
        from: z.number().int().describe('Start of the numeric range, inclusive.'),
        to: z.number().int().describe('End of the numeric range, inclusive.'),
      },
      annotations: { destructiveHint: false },
    },
    async ({ prefix, from, to }): Promise<CallToolResult> => {
      try {
        return textResult({ added: await client.addContainerRange({ prefix, from, to }) });
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'remove_container',
    {
      title: 'Remove a container',
      description: 'Permanently deletes a container and all of its data. This cannot be undone.',
      inputSchema: { id: z.string().describe('The container id to remove.') },
      annotations: { destructiveHint: true },
    },
    async ({ id }): Promise<CallToolResult> => {
      try {
        await client.removeContainer(id);
        return textResult({ removed: id });
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'empty_containers',
    {
      title: 'Empty containers',
      description: 'Resets each given container to vacant: clears its date and ingredients. Does not delete them.',
      inputSchema: { ids: z.array(z.string()).min(1).describe('Container ids to empty.') },
      annotations: { destructiveHint: true },
    },
    async ({ ids }): Promise<CallToolResult> => {
      try {
        return textResult({ emptied: await client.emptyContainers(ids) });
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'update_container',
    {
      title: 'Update a container',
      description: "Overwrites a single container's date, status, and ingredients.",
      inputSchema: {
        id: z.string().describe('The container id to update.'),
        date: dateSchema,
        status: z.enum(STATUS_VALUES),
        ingredients: z.array(ingredientSchema),
      },
      annotations: { destructiveHint: true },
    },
    async ({ id, date, status, ingredients }): Promise<CallToolResult> => {
      try {
        return textResult(await client.updateContainer(id, { date, status, ingredients }));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'create_filling',
    {
      title: 'Fill multiple containers',
      description:
        "Overwrites every target container's date/status/ingredients in one atomic write (e.g. batch-filling several containers with the same dish). Fails without writing anything if any target id is not registered.",
      inputSchema: {
        targetIds: z.array(z.string()).min(1).describe('Container ids to fill.'),
        date: dateSchema,
        status: z.enum(STATUS_VALUES),
        ingredients: z.array(ingredientSchema),
      },
      annotations: { destructiveHint: true },
    },
    async ({ targetIds, date, status, ingredients }): Promise<CallToolResult> => {
      try {
        return textResult({ updated: await client.createFilling({ targetIds, date, status, ingredients }) });
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    'export_data',
    {
      title: 'Export all data',
      description: 'Returns the full registry plus all container data as one JSON document, for backup/inspection.',
      annotations: { readOnlyHint: true },
    },
    async (): Promise<CallToolResult> => {
      try {
        return textResult(await client.exportAll());
      } catch (error) {
        return errorResult(error);
      }
    },
  );
}
