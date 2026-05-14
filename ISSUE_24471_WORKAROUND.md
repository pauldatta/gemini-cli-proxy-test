# Issue #24471: `HttpsProxyAgent is not a constructor`

> Upstream issue: [google-gemini/gemini-cli#24471](https://github.com/google-gemini/gemini-cli/issues/24471)
> Fix PR (not yet merged): [#26361](https://github.com/google-gemini/gemini-cli/pull/26361)

## Status

| Version | Status | Date Verified |
|---------|--------|---------------|
| `v0.42.0` (latest stable) | ❌ **Broken** | 2026-05-14 |
| `v0.44.0-nightly.20260513` | ❌ **Broken** (PR #26361 not merged) | 2026-05-14 |
| `v0.38.0` (GCA accounts) | ✅ Working | 2026-04-27 |

## Root Cause

The Gemini CLI uses `esbuild` to bundle its dependencies into ESM. The `google-auth-library` / `gaxios` dependency dynamically imports `https-proxy-agent` at runtime via:

```js
const { HttpsProxyAgent } = await import('https-proxy-agent');
```

In the bundled ESM output (`chunk-JEW7ZIWE.js`), this dynamic import resolves to a module where the named export `HttpsProxyAgent` is `undefined`. When `gaxios` then calls `new HttpsProxyAgent(...)`, it throws `TypeError: HttpsProxyAgent is not a constructor`.

**This crash is triggered whenever `HTTPS_PROXY` or `HTTP_PROXY` environment variables are set**, regardless of whether you use OAuth or API key authentication. The bug is in the HTTP transport layer, not the auth layer.

## Workaround

[`global-agent`](https://github.com/gajus/global-agent) patches `http.globalAgent` at the Node.js socket level, routing traffic through the proxy *before* `gaxios` runs. Since `HTTPS_PROXY` is never set, `gaxios` never attempts the broken dynamic import.

Works with **all auth methods** — OAuth, GCA, Vertex AI, or API key. No auth changes needed.

### Setup

```bash
# 1. Install global-agent
npm install global-agent

# 2. Create a preload script (preload-proxy.js):
cat > preload-proxy.js << 'EOF'
const { bootstrap } = require('global-agent');
bootstrap();
EOF

# 3. Run Gemini CLI — do NOT set HTTPS_PROXY/HTTP_PROXY
GLOBAL_AGENT_HTTP_PROXY="http://your-proxy:8080" \
GLOBAL_AGENT_HTTPS_PROXY="http://your-proxy:8080" \
NODE_OPTIONS="--require /absolute/path/to/preload-proxy.js" \
gemini
```

For TLS-intercepting proxies, add `NODE_EXTRA_CA_CERTS=/path/to/ca-bundle.crt`.

### Test with this repo

```bash
make test              # reproduces the bug (sets HTTPS_PROXY)
make test-workaround   # validates workaround with existing OAuth/GCA auth
GEMINI_API_KEY=your_key make test-apikey  # validates workaround with API key
```

### Test Results (v0.42.0, macOS, Node v24.6.0)

| Mode | Bug reproduced? | CLI exit | File generated |
|------|----------------|----------|----------------|
| `HTTPS_PROXY` set (default) | Yes — crashes | 1 | No |
| `global-agent` + existing OAuth | No | 0 | Yes |
| `global-agent` + API key | No | 0 | Yes |

### Why it works

| Layer | Default (broken) | Workaround (working) |
|-------|-------------------|----------------------|
| Proxy env var | `HTTPS_PROXY` → detected by `gaxios` → triggers broken `import('https-proxy-agent')` | Not set → `gaxios` never attempts the import |
| Proxy routing | N/A (crashes before routing) | `global-agent` patches `http.globalAgent` → all traffic routed at socket level |
| Auth | Any (irrelevant — crash is in transport) | Any (unchanged) |
