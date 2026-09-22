import type { MiddlewareHandler } from "hono";
import type { Bindings } from "./types";

// Plain `===` on secrets short-circuits on the first differing byte, which
// leaks a timing signal proportional to how many leading bytes matched.
// Hashing both sides to a fixed-length digest first means every comparison
// takes the same shape regardless of where (or whether) the strings
// diverge, and sidesteps needing equal-length inputs for the compare
// itself. `crypto.subtle` is Web Crypto, available globally in the
// Workers runtime without needing `nodejs_compat`.
async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const [digestA, digestB] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(a)),
    crypto.subtle.digest("SHA-256", encoder.encode(b)),
  ]);
  const bytesA = new Uint8Array(digestA);
  const bytesB = new Uint8Array(digestB);
  let diff = 0;
  for (let i = 0; i < bytesA.length; i++) {
    diff |= bytesA[i] ^ bytesB[i];
  }
  return diff === 0;
}

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
  if (!provided || !(await timingSafeEqual(provided, c.env.API_PASSPHRASE))) {
    return c.json({ error: "Unauthorized" }, 401);
  }
  await next();
};
