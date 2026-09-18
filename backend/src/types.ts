export type ContainerStatus = "vacant" | "frozen" | "construction";

export interface Ingredient {
  name: string;
  quantity: string;
}

export interface ContainerRow {
  id: string;
  prefix: string;
  date: string | null;
  status: ContainerStatus;
  ingredients: Ingredient[];
}

export interface Bindings {
  DB: D1Database;
  // Shared secret checked on every request - see src/auth.ts. This app has
  // no multi-user auth, just a single owner keeping strangers out (see
  // CLAUDE.md's "Auth model").
  API_PASSPHRASE: string;
}
