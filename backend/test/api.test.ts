// Runs the real Worker (via `wrangler dev`) against a real local D1
// database and exercises the HTTP API end-to-end - the same checks that
// were manually verified with curl during development, now automated.
//
// This deliberately does NOT use @cloudflare/vitest-pool-workers: the
// version available at the time this was written (0.22.0) has a
// meaningfully different config API than the widely-circulated examples
// (`defineWorkersConfig`/the `/config` subpath don't exist in this
// version's package exports - confirmed by inspecting the installed
// package directly), and the migration path for that API was still
// visibly in flux upstream. Spawning the actual `wrangler dev` process and
// hitting it over HTTP is slower to start but depends on nothing but the
// same two `wrangler` commands a human runs locally (see
// package.json's `dev`/`migrate:local` scripts) - much more stable ground
// to test against.
import { execFileSync } from "node:child_process";
import { spawn, type ChildProcess } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { afterAll, beforeAll, describe, expect, test } from "vitest";

const BACKEND_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const PORT = 28787;
const BASE_URL = `http://127.0.0.1:${PORT}`;
const PASSPHRASE = "test-passphrase";

let persistDir: string;
let worker: ChildProcess;

function authHeaders(): Record<string, string> {
  return {
    Authorization: `Bearer ${PASSPHRASE}`,
    "Content-Type": "application/json",
  };
}

interface ContainerJson {
  id: string;
  prefix: string;
  date: string | null;
  status: string;
  ingredients: { name: string; quantity: string }[];
}

async function json<T>(res: Response): Promise<T> {
  return (await res.json()) as T;
}

async function waitUntilReady(timeoutMs = 20_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${BASE_URL}/health`, {
        headers: authHeaders(),
      });
      if (res.status === 200) return;
    } catch {
      // Not listening yet - keep polling.
    }
    await new Promise((resolve) => setTimeout(resolve, 300));
  }
  throw new Error("wrangler dev did not become ready in time");
}

beforeAll(async () => {
  persistDir = mkdtempSync(path.join(tmpdir(), "frawly-backend-test-"));

  execFileSync(
    "npx",
    [
      "wrangler",
      "d1",
      "migrations",
      "apply",
      "DB",
      "--local",
      "--persist-to",
      persistDir,
    ],
    { cwd: BACKEND_DIR, stdio: "pipe" },
  );

  // `detached: true` puts the process in its own group so the cleanup
  // below can kill it *and* the workerd child it spawns - plain
  // `worker.kill()` only signals the immediate `npx` process and reliably
  // leaves workerd running in the background.
  worker = spawn(
    "npx",
    [
      "wrangler",
      "dev",
      "--port",
      String(PORT),
      "--persist-to",
      persistDir,
      "--var",
      `API_PASSPHRASE:${PASSPHRASE}`,
    ],
    { cwd: BACKEND_DIR, stdio: "ignore", detached: true },
  );

  await waitUntilReady();
}, 30_000);

afterAll(() => {
  if (worker?.pid) {
    try {
      process.kill(-worker.pid, "SIGKILL");
    } catch {
      // Already gone, or the group kill isn't supported here - fall back
      // to signalling just the process we have a handle on.
      worker.kill("SIGKILL");
    }
  }
  try {
    rmSync(persistDir, { recursive: true, force: true });
  } catch {
    // Best-effort cleanup - not worth failing the suite over.
  }
});

async function resetDatabase() {
  await fetch(`${BASE_URL}/import`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({ containers: [] }),
  });
}

describe("auth", () => {
  test("rejects requests with no Authorization header", async () => {
    const res = await fetch(`${BASE_URL}/health`);
    expect(res.status).toBe(401);
  });

  test("rejects requests with the wrong passphrase", async () => {
    const res = await fetch(`${BASE_URL}/health`, {
      headers: { Authorization: "Bearer wrong" },
    });
    expect(res.status).toBe(401);
  });

  test("accepts the correct passphrase", async () => {
    const res = await fetch(`${BASE_URL}/health`, { headers: authHeaders() });
    expect(res.status).toBe(200);
  });
});

describe("CORS", () => {
  // The Flutter web app is served from a different origin than this
  // Worker (GitHub Pages vs *.workers.dev) - without CORS headers, the
  // browser blocks every request before the app ever sees a response,
  // including the connect screen's own reachability check. A plain
  // fetch() here (unlike a real browser) doesn't enforce CORS itself, but
  // it does let us assert the Worker sends the headers a browser needs.
  test("preflight OPTIONS succeeds without a passphrase and allows Authorization", async () => {
    const res = await fetch(`${BASE_URL}/health`, {
      method: "OPTIONS",
      headers: {
        Origin: "https://example.com",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "Authorization",
      },
    });
    expect(res.status).toBe(204);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(res.headers.get("Access-Control-Allow-Headers")).toContain(
      "Authorization",
    );
  });

  test("a real response includes Access-Control-Allow-Origin", async () => {
    const res = await fetch(`${BASE_URL}/health`, { headers: authHeaders() });
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("*");
  });
});

describe("registry: add/remove", () => {
  beforeAll(resetDatabase);

  test("addId then getById round-trips, removeId deletes it", async () => {
    const add = await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "P-1" }),
    });
    expect(add.status).toBe(201);

    const got = await fetch(`${BASE_URL}/containers/P-1`, {
      headers: authHeaders(),
    });
    expect(got.status).toBe(200);
    const body = await json<ContainerJson>(got);
    expect(body).toMatchObject({ id: "P-1", prefix: "P", status: "vacant" });

    const removed = await fetch(`${BASE_URL}/containers/P-1`, {
      method: "DELETE",
      headers: authHeaders(),
    });
    expect(removed.status).toBe(204);

    const goneRes = await fetch(`${BASE_URL}/containers/P-1`, {
      headers: authHeaders(),
    });
    expect(goneRes.status).toBe(404);
  });

  test("addId rejects a duplicate id with 409", async () => {
    await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "P-2" }),
    });
    const dup = await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "P-2" }),
    });
    expect(dup.status).toBe(409);
  });

  test("addId rejects a malformed id with 400", async () => {
    const res = await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "not-valid-id" }),
    });
    expect(res.status).toBe(400);
  });
});

describe("addRange", () => {
  beforeAll(resetDatabase);

  test("skips existing ids instead of failing the whole range", async () => {
    await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "G-2" }),
    });

    const res = await fetch(`${BASE_URL}/containers/range`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ prefix: "G", from: 1, to: 3 }),
    });
    expect(res.status).toBe(200);
    const body = await json<{ added: string[] }>(res);
    expect(new Set(body.added)).toEqual(new Set(["G-1", "G-3"]));

    const registry = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers/registry`, { headers: authHeaders() }),
    );
    expect(registry.map((c) => c.id)).toEqual([
      "G-1",
      "G-2",
      "G-3",
    ]);
  });

  test("rejects a range larger than the 500 cap", async () => {
    const res = await fetch(`${BASE_URL}/containers/range`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ prefix: "Z", from: 1, to: 600 }),
    });
    expect(res.status).toBe(400);
  });

  test("rejects a negative from/to instead of producing malformed ids", async () => {
    const res = await fetch(`${BASE_URL}/containers/range`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ prefix: "P", from: -5, to: 5 }),
    });
    expect(res.status).toBe(400);
  });
});

describe("createFilling", () => {
  beforeAll(resetDatabase);

  test("atomically overwrites every target and drops empty-name ingredients", async () => {
    await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "P-1" }),
    });
    await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "P-2" }),
    });

    const res = await fetch(`${BASE_URL}/fillings`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({
        date: "2026-02-01",
        status: "frozen",
        ingredients: [
          { name: "Soup", quantity: "1L" },
          { name: "", quantity: "discarded" },
        ],
        targetIds: ["P-1", "P-2"],
      }),
    });
    expect(res.status).toBe(200);

    const p1 = await json<ContainerJson>(
      await fetch(`${BASE_URL}/containers/P-1`, { headers: authHeaders() }),
    );
    expect(p1.status).toBe("frozen");
    expect(p1.ingredients).toEqual([{ name: "Soup", quantity: "1L" }]);
  });

  test("rejects the whole write (404) if any target id is unregistered, applying nothing", async () => {
    const res = await fetch(`${BASE_URL}/fillings`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({
        date: "2026-03-01",
        status: "construction",
        ingredients: [],
        targetIds: ["P-1", "P-99"],
      }),
    });
    expect(res.status).toBe(404);

    // P-1 is untouched - still frozen from the previous test, not
    // partially updated to "construction".
    const p1 = await json<ContainerJson>(
      await fetch(`${BASE_URL}/containers/P-1`, { headers: authHeaders() }),
    );
    expect(p1.status).toBe("frozen");
  });
});

describe("emptyContainers", () => {
  beforeAll(resetDatabase);

  test("resets every target to vacant/null date/no ingredients", async () => {
    await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "P-1" }),
    });
    await fetch(`${BASE_URL}/fillings`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({
        date: "2026-02-01",
        status: "frozen",
        ingredients: [{ name: "Soup", quantity: "1L" }],
        targetIds: ["P-1"],
      }),
    });

    const res = await fetch(`${BASE_URL}/containers/empty`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ ids: ["P-1"] }),
    });
    expect(res.status).toBe(200);

    const p1 = await json<ContainerJson>(
      await fetch(`${BASE_URL}/containers/P-1`, { headers: authHeaders() }),
    );
    expect(p1).toMatchObject({ status: "vacant", date: null, ingredients: [] });
  });
});

describe("export / import", () => {
  beforeAll(resetDatabase);

  test("import atomically replaces every row", async () => {
    await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "X-1" }),
    });
    await fetch(`${BASE_URL}/containers`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ id: "X-2" }),
    });

    const res = await fetch(`${BASE_URL}/import`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({
        containers: [
          {
            id: "Y-1",
            date: "2026-04-01",
            status: "frozen",
            ingredients: [{ name: "Curry", quantity: "2 portions" }],
          },
        ],
      }),
    });
    expect(res.status).toBe(200);

    const registry = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers/registry`, { headers: authHeaders() }),
    );
    expect(registry.map((c) => c.id)).toEqual(["Y-1"]);
  });

  test("rejects an invalid import (400) without changing anything", async () => {
    const before = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers/registry`, { headers: authHeaders() }),
    );

    const res = await fetch(`${BASE_URL}/import`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({
        containers: [{ id: "Z-1", date: null, status: "bogus", ingredients: [] }],
      }),
    });
    expect(res.status).toBe(400);

    const after = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers/registry`, { headers: authHeaders() }),
    );
    expect(after).toEqual(before);
  });

  test("export round-trips into import", async () => {
    const exported = await json<{ containers: ContainerJson[] }>(
      await fetch(`${BASE_URL}/export`, { headers: authHeaders() }),
    );
    expect(exported.containers.map((c) => c.id)).toEqual(["Y-1"]);
  });
});

describe("list filtering", () => {
  beforeAll(resetDatabase);

  test("filters by status and search, sorted by date ascending (nulls first)", async () => {
    await fetch(`${BASE_URL}/containers/range`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({ prefix: "P", from: 1, to: 2 }),
    });
    await fetch(`${BASE_URL}/fillings`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify({
        date: "2026-01-01",
        status: "frozen",
        ingredients: [],
        targetIds: ["P-1"],
      }),
    });

    const all = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers`, { headers: authHeaders() }),
    );
    expect(all.map((c) => c.id)).toEqual(["P-2", "P-1"]);

    const frozenOnly = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers?status=frozen`, {
        headers: authHeaders(),
      }),
    );
    expect(frozenOnly.map((c) => c.id)).toEqual(["P-1"]);

    const searched = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers?search=P-2`, {
        headers: authHeaders(),
      }),
    );
    expect(searched.map((c) => c.id)).toEqual(["P-2"]);
  });

  test("treats % and _ in search as literal characters, not LIKE wildcards", async () => {
    // Neither "%" nor "_" appears in any registered id (P-1, P-2), so an
    // unescaped LIKE would wrongly match every row (both are LIKE
    // wildcards); escaped, both should match nothing.
    const percent = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers?search=${encodeURIComponent("%")}`, {
        headers: authHeaders(),
      }),
    );
    expect(percent).toEqual([]);

    const underscore = await json<ContainerJson[]>(
      await fetch(`${BASE_URL}/containers?search=_`, { headers: authHeaders() }),
    );
    expect(underscore).toEqual([]);
  });
});
