# Gemini CLI Proxy Test

This project provides a lightweight local proxy server and an automated test script to simulate running the [Gemini CLI](https://geminicli.com/) from behind a corporate proxy.

If you don't have access to an actual corporate proxy but need to test proxy configuration (like `HTTP_PROXY` and `HTTPS_PROXY` environment variables), this setup allows you to intercept and verify the CLI's outbound network requests.

## Files

- **`proxy.js`**: A minimal Node.js proxy server. It handles standard HTTP requests and supports HTTPS tunneling via the `CONNECT` method (blind tunneling).
- **`test_proxy.sh`**: A bash script that automatically starts the proxy, runs the Gemini CLI in headless mode with proxy environment variables set, and then shuts down the proxy. It also verifies that the traffic was successfully routed.

## Prerequisites

- **Node.js**: Required to run the local proxy server.
- **Gemini CLI**: Must be installed globally (`npm install -g @google/gemini-cli`) and authenticated.

## Usage

### 1. Automated Test (Recommended)

The easiest way to verify the setup is to use the provided Makefile:

```bash
# Ensure Node.js and Gemini CLI are installed
make setup

# Run the automated proxy test
make test

# Clean up log files
make clean
```

**What the test does:**

1. Starts the `proxy.js` server in the background on port `8080`.
2. Pipes a simple prompt ("Reply with 'OK'") into the Gemini CLI.
3. Injects the `HTTP_PROXY` and `HTTPS_PROXY` environment variables.
4. Captures the proxy logs to verify that traffic (e.g., `generativelanguage.googleapis.com`) was routed through the local proxy.
5. Cleans up background processes.

### 2. Manual Testing

If you want to use the proxy interactively with the Gemini CLI:

**Terminal 1 (Start Proxy):**

```bash
node proxy.js
```

**Terminal 2 (Run Gemini CLI):**

```bash
export HTTP_PROXY="http://127.0.0.1:8080"
export HTTPS_PROXY="http://127.0.0.1:8080"

gemini
```

Watch Terminal 1 to see the intercepted `[HTTPS/CONNECT]` requests as the CLI communicates with Google APIs.

## API Endpoints Used by Gemini CLI

When running the Gemini CLI through the proxy, you will observe traffic to the following endpoints. All traffic is encrypted over HTTPS (Port 443):

- **`generativelanguage.googleapis.com`**: The core Gemini API. This is where your prompts are sent and AI responses are generated.
- **`oauth2.googleapis.com`**: Used to refresh your Google OAuth2 access tokens for secure authentication.
- **`registry.npmjs.org`**: The CLI checks the npm registry to see if a newer version of `@google/gemini-cli` is available.
- **`stitch.googleapis.com`**: Connects to Google Workspace's Stitch API, primarily used for extension integrations and telemetry.
- **`play.googleapis.com`**: Occasionally contacted as part of broader Google authentication scopes or telemetry initialization.

## Known Issue: `HttpsProxyAgent is not a constructor` ([#24471](https://github.com/google-gemini/gemini-cli/issues/24471))

### Status

| Version | Status | Date Verified |
|---------|--------|---------------|
| `v0.42.0` (latest stable) | ❌ **Broken** | 2026-05-14 |
| `v0.44.0-nightly.20260513` | ❌ **Broken** (PR [#26361](https://github.com/google-gemini/gemini-cli/pull/26361) not merged) | 2026-05-14 |
| `v0.38.0` (GCA accounts) | ✅ Working | 2026-04-27 |

### Root Cause

The Gemini CLI uses `esbuild` to bundle its dependencies into ESM. The `google-auth-library` / `gaxios` dependency dynamically imports `https-proxy-agent` at runtime via:

```js
const { HttpsProxyAgent } = await import('https-proxy-agent');
```

In the bundled ESM output (`chunk-JEW7ZIWE.js`), this dynamic import resolves to a module where the named export `HttpsProxyAgent` is `undefined`. When `gaxios` then calls `new HttpsProxyAgent(...)`, it throws `TypeError: HttpsProxyAgent is not a constructor`.

**This crash is triggered whenever `HTTPS_PROXY` or `HTTP_PROXY` environment variables are set**, regardless of whether you use OAuth or API key authentication. The bug is in the HTTP transport layer, not the auth layer.

### ✅ Verified Workaround

We've validated a workaround that bypasses the broken `gaxios` code path entirely using [`global-agent`](https://github.com/gajus/global-agent), which patches Node's `http.globalAgent` at the socket level — before any library code runs.

**How it works:**

1. **Do NOT set `HTTPS_PROXY` / `HTTP_PROXY`** — these trigger the broken `gaxios` dynamic import.
2. **Use `global-agent`** to route traffic through the proxy at Node's HTTP agent level.
3. **Use `GEMINI_API_KEY`** for authentication (optional but recommended to avoid OAuth retry delays).

#### Quick Setup

```bash
# 1. Install global-agent in your project or globally
npm install global-agent

# 2. Create a preload script (preload-proxy.js):
cat > preload-proxy.js << 'EOF'
const { bootstrap } = require('global-agent');
bootstrap();
EOF

# 3. Run Gemini CLI with the workaround:
GLOBAL_AGENT_HTTP_PROXY="http://your-proxy:8080" \
GLOBAL_AGENT_HTTPS_PROXY="http://your-proxy:8080" \
NODE_OPTIONS="--require /absolute/path/to/preload-proxy.js" \
GEMINI_API_KEY="your-api-key" \
gemini
```

> **Note for corporate proxies with custom CA certificates:** You may also need `NODE_TLS_REJECT_UNAUTHORIZED=0` or `NODE_EXTRA_CA_CERTS=/path/to/ca-bundle.crt` depending on your proxy's TLS inspection setup.

#### Test it with this repo

```bash
# Run the workaround test (uses global-agent, no HTTPS_PROXY)
GEMINI_API_KEY=your_key make test-apikey

# Compare with the broken default (uses HTTPS_PROXY, triggers bug)
make test
```

#### Why This Works

| Layer | Default (broken) | Workaround (working) |
|-------|-------------------|----------------------|
| Proxy env var | `HTTPS_PROXY` → detected by `gaxios` → triggers broken `import('https-proxy-agent')` | Not set → `gaxios` never attempts the import |
| Proxy routing | N/A (crashes before routing) | `global-agent` patches `http.globalAgent` → all HTTP/HTTPS goes through proxy at socket level |
| Auth | OAuth or API key (irrelevant — crash is in transport) | `GEMINI_API_KEY` (avoids OAuth token refresh delays) |

---

## Community Test Results — GCA Licensed Accounts

> **Context**: The sections above document endpoints observed with personal/API-key authentication. The results below were captured using **GCA (Gemini Code Assist) licensed accounts** to identify which domains need to be allowlisted in corporate proxy environments.

### Test: Google Workspace Account with GCA License

- **Contributor**: @arungk27
- **CLI Version**: Gemini CLI v0.38.0
- **Account Type**: Google Workspace (GCA licensed)
- **Date**: 2026-04-27

#### Domains Observed

| Domain | Port | Requests | Purpose |
|--------|------|----------|---------|
| `cloudcode-pa.googleapis.com` | 443 | 14 | Core Gemini Code Assist API (prompts & responses) |
| `oauth2.googleapis.com` | 443 | 2 | OAuth2 token refresh |
| `us-npm.pkg.dev` | 443 | 3 | Google Artifact Registry (extension/package updates) |
| `play.googleapis.com` | 443 | 2 | Telemetry & auth scope initialization |

> **Note**: `api.githubcopilot.com:443` (1 request) was also observed but is from a locally configured MCP extension, not core Gemini CLI traffic.

#### Minimum Proxy Allowlist for GCA Users

```
cloudcode-pa.googleapis.com:443
oauth2.googleapis.com:443
us-npm.pkg.dev:443
play.googleapis.com:443
```

#### Notable Differences from Personal Accounts

- GCA accounts use **`cloudcode-pa.googleapis.com`** instead of `generativelanguage.googleapis.com`
- GCA accounts use **`us-npm.pkg.dev`** (Google Artifact Registry) instead of `registry.npmjs.org`
- `stitch.googleapis.com` was **not observed** with GCA accounts
- The `HttpsProxyAgent is not a constructor` bug **did not occur** on v0.38.0

#### Raw Proxy Log

```
[HTTPS/CONNECT] oauth2.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] oauth2.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] api.githubcopilot.com:443
[HTTPS/CONNECT] play.googleapis.com:443
[HTTPS/CONNECT] play.googleapis.com:443
[HTTPS/CONNECT] us-npm.pkg.dev:443
[HTTPS/CONNECT] us-npm.pkg.dev:443
[HTTPS/CONNECT] us-npm.pkg.dev:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
[HTTPS/CONNECT] cloudcode-pa.googleapis.com:443
```

### Add Your Results

If you have tested with a different account type or license, please add your findings above and submit a PR.
