# Gemini CLI Proxy Test

Domain allowlists and proxy configuration for running [Gemini CLI](https://geminicli.com/) behind corporate firewalls.

## Domain Allowlist

### Personal / API Key Accounts

| Domain | Port | Purpose |
|--------|------|---------|
| `generativelanguage.googleapis.com` | 443 | Core Gemini API (prompts & responses) |
| `oauth2.googleapis.com` | 443 | OAuth2 token refresh |
| `registry.npmjs.org` | 443 | CLI update checks (npm registry) |
| `stitch.googleapis.com` | 443 | Extension integrations & telemetry |
| `play.googleapis.com` | 443 | Auth scope initialization & telemetry |

### GCA (Gemini Code Assist) Licensed Accounts

> Contributed by @arungk27 — CLI v0.38.0, Google Workspace account

| Domain | Port | Purpose |
|--------|------|---------|
| `cloudcode-pa.googleapis.com` | 443 | Core Gemini Code Assist API (prompts & responses) |
| `oauth2.googleapis.com` | 443 | OAuth2 token refresh |
| `us-npm.pkg.dev` | 443 | Google Artifact Registry (extension/package updates) |
| `play.googleapis.com` | 443 | Telemetry & auth scope initialization |

**Key differences from personal accounts:**
- `cloudcode-pa.googleapis.com` replaces `generativelanguage.googleapis.com`
- `us-npm.pkg.dev` replaces `registry.npmjs.org`
- `stitch.googleapis.com` not observed

### Minimum Allowlist (copy-paste)

**Personal accounts:**
```
generativelanguage.googleapis.com:443
oauth2.googleapis.com:443
registry.npmjs.org:443
stitch.googleapis.com:443
play.googleapis.com:443
```

**GCA accounts:**
```
cloudcode-pa.googleapis.com:443
oauth2.googleapis.com:443
us-npm.pkg.dev:443
play.googleapis.com:443
```

---

## ⚠️ Known Issue: Proxy Support Broken ([#24471](https://github.com/google-gemini/gemini-cli/issues/24471))

Setting `HTTPS_PROXY` / `HTTP_PROXY` crashes the CLI with `TypeError: HttpsProxyAgent is not a constructor`. Broken on v0.42.0 and nightly. A workaround using `global-agent` is available and works with all auth methods (OAuth, GCA, Vertex, API key).

**→ [Full root cause analysis and workaround instructions](ISSUE_24471_WORKAROUND.md)**

```bash
# Quick version — see linked doc for details
npm install global-agent
GLOBAL_AGENT_HTTP_PROXY=http://your-proxy:8080 \
GLOBAL_AGENT_HTTPS_PROXY=http://your-proxy:8080 \
NODE_OPTIONS="--require $(pwd)/preload-proxy.js" \
gemini   # do NOT set HTTPS_PROXY
```

---

## Test Harness

This repo also includes a local proxy server and automated test scripts for validating proxy configurations.

### Files

- **`proxy.js`** — Minimal Node.js proxy with HTTP and HTTPS CONNECT tunneling
- **`test_proxy.sh`** — Automated test: starts proxy, runs CLI in headless mode, verifies traffic routing
- **`preload-proxy.js`** — `global-agent` bootstrapper for the workaround

### Usage

```bash
make setup             # install prerequisites
make test              # reproduces bug #24471 (sets HTTPS_PROXY)
make test-workaround   # validates workaround with existing OAuth/GCA auth
GEMINI_API_KEY=key make test-apikey  # validates workaround with API key
make clean             # cleanup
```

### Raw Proxy Log — GCA Account

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

> `api.githubcopilot.com` is from a local MCP extension, not core CLI traffic.

---

### Add Your Results

If you have tested with a different account type or license, add your findings and submit a PR.
