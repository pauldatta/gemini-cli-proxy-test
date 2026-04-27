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

### 1. Automated Test

The easiest way to verify the setup is to run the automated bash script:

```bash
chmod +x test_proxy.sh
./test_proxy.sh
```

**What it does:**

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

## Known Issues (CLI Bug)

_Note: As of the time of writing, running the Gemini CLI with proxy environment variables exposes an internal bug in the CLI itself._

While the proxy successfully intercepts the traffic, the Gemini CLI may crash with the following error:

```
TypeError: HttpsProxyAgent is not a constructor
```

This indicates that the CLI is correctly attempting to route traffic through the proxy, but fails during the initialization of its internal HTTP client. This test environment successfully isolates the issue.
