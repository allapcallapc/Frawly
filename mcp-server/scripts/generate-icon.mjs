#!/usr/bin/env node
// Regenerates src/icon.generated.ts (gitignored) from ../../assets/logo.png
// - the same source flutter_launcher_icons uses for the app's own
// launcher/PWA icons (see ../../.github/actions/generate-app-icons) - so
// the MCP connector's icon can never drift out of sync with the app's, and
// changing the logo only ever means changing that one file. Runs
// automatically before typecheck/test/dev/deploy (see package.json).
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import sharp from 'sharp';

const here = path.dirname(fileURLToPath(import.meta.url));
const sourcePath = path.join(here, '..', '..', 'assets', 'logo.png');
const outPath = path.join(here, '..', 'src', 'icon.generated.ts');

// Small enough to keep the MCP initialize response light, crisp enough for
// a connector picker's icon (typically rendered well under 128px).
const ICON_SIZE = 128;

const resized = await sharp(await readFile(sourcePath))
  .resize(ICON_SIZE, ICON_SIZE)
  .png()
  .toBuffer();

const dataUri = `data:image/png;base64,${resized.toString('base64')}`;

const contents = `// GENERATED FILE - do not edit by hand.
// Regenerate with \`pnpm run generate-icon\` (also runs automatically
// before typecheck/test/dev/deploy - see package.json) whenever
// ../../assets/logo.png changes.
export const FRAWLY_ICON_DATA_URI = ${JSON.stringify(dataUri)};
`;

await writeFile(outPath, contents);
console.log(`Wrote ${outPath} (${(dataUri.length / 1024).toFixed(1)} KiB) from ${sourcePath}`);
