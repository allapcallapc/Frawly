#!/usr/bin/env node
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

import { FrawlyClient } from './client.js';
import { registerFrawlyTools } from './tools.js';

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    console.error(
      `Missing required environment variable ${name}. Set FRAWLY_BACKEND_URL and FRAWLY_PASSPHRASE to the ` +
        'same values you would enter on the app\'s connect screen (see mcp-server/README.md).',
    );
    process.exit(1);
  }
  return value;
}

async function main(): Promise<void> {
  const backendUrl = requireEnv('FRAWLY_BACKEND_URL');
  const passphrase = requireEnv('FRAWLY_PASSPHRASE');

  const client = new FrawlyClient({ backendUrl, passphrase });
  if (!(await client.health())) {
    console.error(
      `Could not reach a Frawly backend at ${backendUrl} with the given passphrase. Check FRAWLY_BACKEND_URL/` +
        'FRAWLY_PASSPHRASE.',
    );
    process.exit(1);
  }

  const server = new McpServer({ name: 'frawly-mcp-server', version: '0.1.0' });
  registerFrawlyTools(server, client);

  await server.connect(new StdioServerTransport());
}

main().catch((error: unknown) => {
  console.error('frawly-mcp-server failed to start:', error);
  process.exit(1);
});
