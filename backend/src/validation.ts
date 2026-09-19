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
