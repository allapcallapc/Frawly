import type { ContainerStatus, Ingredient } from "./types";

const STATUSES: readonly ContainerStatus[] = [
  "vacant",
  "frozen",
  "construction",
];

// Must match the `id` CHECK constraint in migrations/0001_initial_schema.sql.
const ID_PATTERN = /^[A-Za-z0-9]+-[0-9]+$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

export function isValidStatus(value: unknown): value is ContainerStatus {
  return typeof value === "string" && (STATUSES as string[]).includes(value);
}

export function isValidId(value: unknown): value is string {
  return typeof value === "string" && ID_PATTERN.test(value);
}

/** Accepts null (vacant) or a well-formed "YYYY-MM-DD" string. */
export function isValidDateOrNull(value: unknown): value is string | null {
  if (value === null || value === undefined) return true;
  if (typeof value !== "string" || !DATE_PATTERN.test(value)) return false;
  return !Number.isNaN(Date.parse(value));
}

/**
 * Escapes SQLite LIKE's wildcard characters (`%`, `_`) and the escape
 * character itself, so a search term is matched literally instead of a
 * stray `%`/`_` in it being treated as a wildcard. Pair with `escape '\'`
 * on the LIKE clause.
 */
export function escapeLikePattern(value: string): string {
  return value.replace(/[\\%_]/g, (char) => `\\${char}`);
}

/**
 * Normalises a container search term so separators don't have to be typed
 * exactly: whitespace and dash variants (en/em dash, minus sign) become a
 * plain "-", and a bare letters-then-digits term gets the hyphen inserted
 * ("G5" -> "g-5"). Lowercased, for a literal match on `lower(id)`. Mirrors
 * `normalizeContainerSearch` in `lib/utils/container_search.dart`, so the
 * app's home list and `GET /containers` agree. Only the term is rewritten,
 * never the ids, so "G25" finds "G-25" but never "G2-5".
 */
export function normalizeSearch(value: string): string {
  const cleaned = value
    .trim()
    .toLowerCase()
    .replace(/[\s\-\u2010-\u2015\u2212]+/g, "-");
  const match = /^([a-z]+)([0-9]+)$/.exec(cleaned);
  return match ? `${match[1]}-${match[2]}` : cleaned;
}

/** Drops empty-name rows silently, matching every other write path's rule. */
export function sanitizeIngredients(raw: unknown): Ingredient[] {
  if (!Array.isArray(raw)) return [];
  const result: Ingredient[] = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== "object") continue;
    const name = (entry as Record<string, unknown>).name;
    const quantity = (entry as Record<string, unknown>).quantity;
    if (typeof name === "string" && name.trim().length > 0) {
      result.push({
        name,
        quantity: typeof quantity === "string" ? quantity : "",
      });
    }
  }
  return result;
}
