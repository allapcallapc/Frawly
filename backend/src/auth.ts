import type { MiddlewareHandler } from "hono";
import type { Bindings } from "./types";

// This app has no multi-user auth - a single shared passphrase is enough
// to keep the app "just for me" instead of open to anyone who finds the
// URL (see CLAUDE.md's "Auth model"). Checked on every request, /health
// included, so the app's connect flow verifies both reachability and the
// passphrase in one call.
export const requirePassphrase: MiddlewareHandler<{
  Bindings: Bindings;
}> = async (c, next) => {
  const header = c.req.header("Authorization") ?? "";
  const provided = header.startsWith("Bearer ")
    ? header.slice("Bearer ".length)
    : "";
  if (!provided || provided !== c.env.API_PASSPHRASE) {
    return c.json({ error: "Unauthorized" }, 401);
  }
  await next();
};
