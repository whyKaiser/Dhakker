# Running the assistant Worker locally

## The supported way: in-process

```bash
node --test assistant-proxy/worker.test.mjs      # 131 tests
```

`worker.js` exports a standard module Worker (`export default { fetch }`), so
its entry point can be called directly with a `Request` and a plain `env`
object. That is how the test suite drives it, and it is the supported local
workflow.

To exercise a path by hand, import it and call `fetch` with fake config —
**replace `globalThis.fetch` with something that throws first**, so a mistake
cannot reach a real provider:

```js
import worker from "./assistant-proxy/worker.js";

globalThis.fetch = async (url) => {
  throw new Error(`blocked outbound call: ${url}`);
};

const env = {
  ENVIRONMENT: "production",
  FIREBASE_PROJECT_ID: "example-project",   // any non-empty value
  ALLOWED_ORIGINS: "https://allowed.example",
};

const res = await worker.fetch(
  new Request("https://worker.local/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ messages: [{ role: "user", content: "test" }] }),
  }),
  env,
  {},
);

console.log(res.status, await res.text());   // 401 — no token in production
```

Every gate before the provider call — CORS, origin allow-list, method,
body size, JSON validity, the fail-closed missing-`FIREBASE_PROJECT_ID`
check, auth, rate limiting, schema validation — runs fully this way, with no
key and no network.

## Why there is no `wrangler.toml`

A committed `wrangler.toml` would have to name a real account, a real Worker
and real bindings to be useful for `wrangler dev`, and would then be a
standing description of production topology sitting in a public repository.
The one thing it could not carry is the part that actually matters —
`GROQ_API_KEY` and `GEMINI_API_KEY` are Cloudflare secrets and are never in
the repo — so `wrangler dev` would need them supplied out of band anyway.

Weighed against a test suite that already drives the real entry point with no
credentials at all, the file earns its risk only for someone deploying, and
that person is configuring the Worker in the Cloudflare dashboard regardless.

If you do want `wrangler dev` locally, create an **uncommitted**
`wrangler.toml` (it is covered by `.gitignore`):

```toml
name = "dhakker-assistant-proxy-dev"
main = "worker.js"
compatibility_date = "2024-11-01"

[vars]
ENVIRONMENT = "development"
FIREBASE_PROJECT_ID = "<your dev project id>"
ALLOWED_ORIGINS = "http://localhost:8080"
```

Then `wrangler secret put GROQ_API_KEY` — never as a `[vars]` entry, and
never in a file you commit.

## Deployment configuration

The variables the Worker expects in production are listed in the README, and
the reasoning behind each is in `docs/ARCHITECTURE.md`. `ENVIRONMENT`,
`FIREBASE_PROJECT_ID` and `ALLOWED_ORIGINS` are the three that change its
security posture; a missing `FIREBASE_PROJECT_ID` makes it refuse every
request with `503` rather than skip token validation.
