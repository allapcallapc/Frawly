import { Hono } from "hono";
import { requirePassphrase } from "./auth";
import { parseRow } from "./db";
import type { Bindings, ContainerStatus, Ingredient } from "./types";
import {
  isValidDateOrNull,
  isValidId,
  isValidStatus,
  sanitizeIngredients,
} from "./validation";

interface RawRow {
  id: string;
  prefix: string;
  date: string | null;
  status: string;
  ingredients: string;
}

const MAX_RANGE_SIZE = 500;
const LIST_COLUMNS =
  "id, prefix, date, status, ingredients" as const;
// SQLite's default ORDER BY ASC already puts NULLs first, which is exactly
// the "vacant containers first" ordering the spec asks for - no explicit
// NULLS FIRST needed (unlike Postgres).
const HOME_ORDER = "order by date asc, id asc" as const;
// No split_part() in SQLite - the numeric suffix is pulled out with
// substr()/instr() so "P-2" sorts before "P-10" (a plain text sort
// wouldn't).
const REGISTRY_ORDER =
  "order by prefix asc, cast(substr(id, instr(id, '-') + 1) as integer) asc" as const;

const app = new Hono<{ Bindings: Bindings }>();

app.use("*", requirePassphrase);

app.get("/health", (c) => c.json({ ok: true }));

app.get("/containers/registry", async (c) => {
  const { results } = await c.env.DB.prepare(
    `select ${LIST_COLUMNS} from containers ${REGISTRY_ORDER}`,
  ).all<RawRow>();
  return c.json(results.map(parseRow));
});

app.post("/containers/range", async (c) => {
  const body = await c.req.json().catch(() => null);
  const prefix =
    typeof body?.prefix === "string" ? body.prefix.trim() : "";
  const from = body?.from;
  const to = body?.to;

  if (!prefix) {
    return c.json({ error: "Prefix must not be empty." }, 400);
  }
  if (
    typeof from !== "number" ||
    typeof to !== "number" ||
    !Number.isInteger(from) ||
    !Number.isInteger(to)
  ) {
    return c.json({ error: "from/to must be integers." }, 400);
  }
  if (to < from) {
    return c.json({ error: "Range end must not be before its start." }, 400);
  }
  const count = to - from + 1;
  if (count > MAX_RANGE_SIZE) {
    return c.json(
      {
        error: `Range is too large (${count} ids) - the limit is ${MAX_RANGE_SIZE}.`,
      },
      400,
    );
  }

  const ids = Array.from({ length: count }, (_, i) => `${prefix}-${from + i}`);
  const placeholders = ids.map(() => "(?)").join(", ");
  const { results } = await c.env.DB.prepare(
    `insert into containers (id) values ${placeholders} on conflict (id) do nothing returning id`,
  )
    .bind(...ids)
    .all<{ id: string }>();

  return c.json({ added: results.map((r) => r.id) });
});

app.post("/containers/empty", async (c) => {
  const body = await c.req.json().catch(() => null);
  const ids: unknown = body?.ids;
  if (!Array.isArray(ids) || !ids.every((v) => typeof v === "string")) {
    return c.json({ error: "ids must be an array of strings." }, 400);
  }
  if (ids.length === 0) {
    return c.json({ emptied: [] });
  }
  const uniqueIds = [...new Set(ids as string[])];
  const placeholders = uniqueIds.map(() => "?").join(", ");
  await c.env.DB.prepare(
    `update containers set date = null, status = 'vacant', ingredients = '[]', updated_at = datetime('now') where id in (${placeholders})`,
  )
    .bind(...uniqueIds)
    .run();
  return c.json({ emptied: uniqueIds });
});

app.get("/containers", async (c) => {
  const status = c.req.query("status");
  const search = c.req.query("search");
  if (status !== undefined && !isValidStatus(status)) {
    return c.json({ error: `Invalid status "${status}".` }, 400);
  }

  const conditions: string[] = [];
  const params: unknown[] = [];
  if (status) {
    conditions.push("status = ?");
    params.push(status);
  }
  if (search && search.trim()) {
    conditions.push("id like ?");
    params.push(`%${search.trim()}%`);
  }
  const where = conditions.length ? `where ${conditions.join(" and ")}` : "";

  const { results } = await c.env.DB.prepare(
    `select ${LIST_COLUMNS} from containers ${where} ${HOME_ORDER}`,
  )
    .bind(...params)
    .all<RawRow>();

  return c.json(results.map(parseRow));
});

app.post("/containers", async (c) => {
  const body = await c.req.json().catch(() => null);
  const id = body?.id;
  if (!isValidId(id)) {
    return c.json({ error: 'id must look like "Prefix-Number".' }, 400);
  }
  try {
    await c.env.DB.prepare("insert into containers (id) values (?)")
      .bind(id)
      .run();
  } catch (e) {
    if (String(e).includes("UNIQUE constraint failed")) {
      return c.json({ error: `Container id "${id}" already exists.` }, 409);
    }
    throw e;
  }
  return c.json({ id }, 201);
});

app.get("/containers/:id", async (c) => {
  const id = c.req.param("id");
  const row = await c.env.DB.prepare(
    `select ${LIST_COLUMNS} from containers where id = ?`,
  )
    .bind(id)
    .first<RawRow>();
  if (!row) return c.json({ error: "Not found" }, 404);
  return c.json(parseRow(row));
});

app.patch("/containers/:id", async (c) => {
  const id = c.req.param("id");
  const body = await c.req.json().catch(() => null);
  if (!isValidDateOrNull(body?.date)) {
    return c.json({ error: "Invalid date." }, 400);
  }
  if (!isValidStatus(body?.status)) {
    return c.json({ error: "Invalid status." }, 400);
  }
  const ingredients = sanitizeIngredients(body?.ingredients);

  const row = await c.env.DB.prepare(
    `update containers set date = ?, status = ?, ingredients = ?, updated_at = datetime('now') where id = ?
     returning ${LIST_COLUMNS}`,
  )
    .bind(body.date ?? null, body.status, JSON.stringify(ingredients), id)
    .first<RawRow>();

  if (!row) return c.json({ error: "Not found" }, 404);
  return c.json(parseRow(row));
});

app.delete("/containers/:id", async (c) => {
  const id = c.req.param("id");
  await c.env.DB.prepare("delete from containers where id = ?")
    .bind(id)
    .run();
  return c.body(null, 204);
});

app.post("/fillings", async (c) => {
  const body = await c.req.json().catch(() => null);
  const targetIds: unknown = body?.targetIds;
  if (
    !Array.isArray(targetIds) ||
    targetIds.length === 0 ||
    !targetIds.every((v) => typeof v === "string")
  ) {
    return c.json(
      { error: "targetIds must be a non-empty array of strings." },
      400,
    );
  }
  if (!isValidDateOrNull(body?.date)) {
    return c.json({ error: "Invalid date." }, 400);
  }
  if (!isValidStatus(body?.status)) {
    return c.json({ error: "Invalid status." }, 400);
  }
  const ingredients = sanitizeIngredients(body?.ingredients);

  const uniqueIds = [...new Set(targetIds as string[])];
  const placeholders = uniqueIds.map(() => "?").join(", ");
  const { results: existing } = await c.env.DB.prepare(
    `select id from containers where id in (${placeholders})`,
  )
    .bind(...uniqueIds)
    .all<{ id: string }>();
  const existingSet = new Set(existing.map((r) => r.id));
  const missing = uniqueIds.filter((id) => !existingSet.has(id));
  if (missing.length > 0) {
    return c.json(
      { error: "Container id(s) not in the registry.", missing },
      404,
    );
  }

  // A single UPDATE ... WHERE id IN (...) is one atomic statement - every
  // target is overwritten or none are, same guarantee the old
  // PostgREST-based backend had, just via our own SQL now instead of a
  // client-side PostgREST request.
  await c.env.DB.prepare(
    `update containers set date = ?, status = ?, ingredients = ?, updated_at = datetime('now') where id in (${placeholders})`,
  )
    .bind(body.date ?? null, body.status, JSON.stringify(ingredients), ...uniqueIds)
    .run();

  return c.json({ updated: uniqueIds });
});

app.get("/export", async (c) => {
  const { results } = await c.env.DB.prepare(
    `select ${LIST_COLUMNS} from containers ${REGISTRY_ORDER}`,
  ).all<RawRow>();
  const containers = results.map(parseRow);
  return c.json({
    version: 1,
    exportedAt: new Date().toISOString(),
    containers: containers.map((row) => ({
      id: row.id,
      date: row.date,
      status: row.status,
      ingredients: row.ingredients,
    })),
  });
});

app.post("/import", async (c) => {
  const body = await c.req.json().catch(() => null);
  const rawContainers = body?.containers;
  if (!Array.isArray(rawContainers)) {
    return c.json({ error: 'Missing or invalid "containers" list.' }, 400);
  }

  const validated: {
    id: string;
    date: string | null;
    status: ContainerStatus;
    ingredients: Ingredient[];
  }[] = [];
  const seenIds = new Set<string>();
  for (let i = 0; i < rawContainers.length; i++) {
    const entry = rawContainers[i];
    if (!entry || typeof entry !== "object") {
      return c.json({ error: `containers[${i}] is not an object.` }, 400);
    }
    const record = entry as Record<string, unknown>;
    if (!isValidId(record.id)) {
      return c.json(
        { error: `containers[${i}].id must look like "Prefix-Number".` },
        400,
      );
    }
    if (seenIds.has(record.id)) {
      return c.json(
        { error: `Duplicate id "${record.id}" in import file.` },
        400,
      );
    }
    seenIds.add(record.id);
    if (!isValidDateOrNull(record.date)) {
      return c.json(
        { error: `containers[${i}].date is not a valid date.` },
        400,
      );
    }
    if (!isValidStatus(record.status)) {
      return c.json(
        {
          error: `containers[${i}].status is not one of vacant/frozen/construction.`,
        },
        400,
      );
    }
    validated.push({
      id: record.id,
      date: (record.date as string | null | undefined) ?? null,
      status: record.status,
      ingredients: sanitizeIngredients(record.ingredients),
    });
  }

  // D1's batch() runs every statement in one implicit transaction - this
  // is the atomic full-table replace that used to need a dedicated
  // Postgres RPC function (see the repo history); owning the whole
  // backend now means it's just normal application code.
  const statements = [
    c.env.DB.prepare("delete from containers"),
    ...validated.map((row) =>
      c.env.DB.prepare(
        "insert into containers (id, date, status, ingredients) values (?, ?, ?, ?)",
      ).bind(row.id, row.date, row.status, JSON.stringify(row.ingredients)),
    ),
  ];
  await c.env.DB.batch(statements);

  return c.json({ imported: validated.length });
});

export default app;
