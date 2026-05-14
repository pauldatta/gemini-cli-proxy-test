# Gemini CLI Proxy Test

Local proxy server and test harness for verifying [Gemini CLI](https://geminicli.com/) connectivity behind corporate proxies. Use the domain allowlists below to configure your firewall rules, or run the test suite to validate your proxy setup.

**Tested with:** Gemini CLI v0.42.0 · Node.js v24.6.0 · macOS

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

## Test Harness

This repo includes a local proxy server and automated tests for validating proxy configurations.

### Files

- **`proxy.js`** — Minimal Node.js proxy with HTTP and HTTPS CONNECT tunneling
- **`test_proxy.sh`** — Automated test: starts proxy, runs CLI in headless mode, verifies traffic routing
- **`preload-proxy.js`** — `global-agent` bootstrapper for the workaround

### Usage

```bash
make setup             # install prerequisites
make test              # run proxy test (default OAuth auth)
make test-workaround   # test with global-agent workaround (see below)
GEMINI_API_KEY=key make test-apikey  # test with API key auth
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

## Known Issue

Setting `HTTPS_PROXY` / `HTTP_PROXY` crashes the CLI with `TypeError: HttpsProxyAgent is not a constructor` ([#24471](https://github.com/google-gemini/gemini-cli/issues/24471)). A `global-agent` workaround is available — see [ISSUE_24471_WORKAROUND.md](ISSUE_24471_WORKAROUND.md) for details.

---

### Add Your Results

If you have tested with a different account type or license, add your findings and submit a PR.
