import type { ContainerRow } from "./types";

interface RawRow {
  id: string;
  prefix: string;
  date: string | null;
  status: string;
  ingredients: string;
}

export function parseRow(row: RawRow): ContainerRow {
  return {
    id: row.id,
    prefix: row.prefix,
    date: row.date,
    status: row.status as ContainerRow["status"],
    ingredients: JSON.parse(row.ingredients),
  };
}
