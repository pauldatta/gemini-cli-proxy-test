#!/bin/bash
set -euo pipefail

# --- Configuration ---
PROXY_PORT=8080
PROXY_TIMEOUT=5        # seconds to wait for proxy to start
CLI_TIMEOUT=120        # seconds before killing the Gemini CLI
PROMPT="Write a python script in ./tmp/hello.py that calculates the Fibonacci sequence up to 10"

# --- Parse mode ---
AUTH_MODE="${1:-oauth}"  # "oauth" (triggers bug), "apikey" (workaround+key), "workaround" (global-agent, existing auth)

case "$AUTH_MODE" in
  apikey)
    if [ -z "${GEMINI_API_KEY:-}" ]; then
      echo "❌ GEMINI_API_KEY is not set. Get one from https://aistudio.google.com/apikey"
      exit 1
    fi
    echo "=== Mode: API Key + global-agent (bypasses gaxios + uses API key) ==="
    ;;
  workaround)
    echo "=== Mode: global-agent only (existing OAuth/GCA auth, no HTTPS_PROXY) ==="
    ;;
  oauth)
    echo "=== Mode: OAuth + HTTPS_PROXY (default — reproduces issue #24471) ==="
    ;;
  *)
    echo "Usage: $0 [oauth|apikey|workaround]"
    exit 1
    ;;
esac

# --- Cleanup trap ---
cleanup() {
  if [ -n "${PROXY_PID:-}" ] && kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "Cleaning up proxy (PID $PROXY_PID)..."
    kill "$PROXY_PID" 2>/dev/null || true
    wait "$PROXY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# --- Start proxy ---
echo "Starting proxy server on port $PROXY_PORT..."
node proxy.js > proxy.log 2>&1 &
PROXY_PID=$!

# Wait for proxy to be ready
for i in $(seq 1 "$PROXY_TIMEOUT"); do
  if curl -s -o /dev/null --connect-timeout 1 -x "http://127.0.0.1:$PROXY_PORT" http://example.com 2>/dev/null; then
    echo "Proxy ready (PID $PROXY_PID)."
    break
  fi
  if [ "$i" -eq "$PROXY_TIMEOUT" ]; then
    echo "❌ Proxy failed to start within ${PROXY_TIMEOUT}s."
    cat proxy.log
    exit 1
  fi
  sleep 1
done

# --- Build env vars for the CLI ---
setup_global_agent() {
  # Shared setup for apikey and workaround modes.
  # Uses global-agent to route traffic through the proxy at the Node HTTP agent
  # level, completely avoiding the broken gaxios dynamic import of https-proxy-agent.
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [ ! -d "$SCRIPT_DIR/node_modules/global-agent" ]; then
    echo "Installing global-agent (one-time)..."
    npm install --prefix "$SCRIPT_DIR" global-agent 2>&1
  fi
  GLOBAL_AGENT_VARS="GLOBAL_AGENT_HTTP_PROXY=http://127.0.0.1:$PROXY_PORT GLOBAL_AGENT_HTTPS_PROXY=http://127.0.0.1:$PROXY_PORT GLOBAL_AGENT_NO_PROXY=''"
  NODE_OPTS="NODE_OPTIONS=--require=$SCRIPT_DIR/preload-proxy.js"
}

case "$AUTH_MODE" in
  apikey)
    setup_global_agent
    CLI_ENV="GEMINI_API_KEY=$GEMINI_API_KEY $GLOBAL_AGENT_VARS $NODE_OPTS NODE_TLS_REJECT_UNAUTHORIZED=0"
    ;;
  workaround)
    setup_global_agent
    # No GEMINI_API_KEY — uses existing OAuth/GCA/Vertex auth from ~/.gemini/
    CLI_ENV="$GLOBAL_AGENT_VARS $NODE_OPTS NODE_TLS_REJECT_UNAUTHORIZED=0"
    ;;
  oauth)
    CLI_ENV="HTTPS_PROXY=http://127.0.0.1:$PROXY_PORT HTTP_PROXY=http://127.0.0.1:$PROXY_PORT"
    ;;
esac

# --- Run Gemini CLI with timeout ---
echo "Running Gemini CLI with proxy (timeout: ${CLI_TIMEOUT}s)..."
mkdir -p ./tmp

CLI_EXIT=0
# Detect timeout command
if command -v gtimeout &>/dev/null; then
  TIMEOUT_CMD="gtimeout"
elif command -v timeout &>/dev/null; then
  TIMEOUT_CMD="timeout"
else
  TIMEOUT_CMD=""
fi

if [ -n "$TIMEOUT_CMD" ]; then
  echo "$PROMPT" | \
    env $CLI_ENV \
    $TIMEOUT_CMD "$CLI_TIMEOUT" gemini --yolo 2>&1 || CLI_EXIT=$?
else
  echo "$PROMPT" | \
    env $CLI_ENV \
    gemini --yolo 2>&1 &
  CLI_PID=$!
  ( sleep "$CLI_TIMEOUT" && kill "$CLI_PID" 2>/dev/null ) &
  WATCHDOG_PID=$!
  wait "$CLI_PID" 2>/dev/null || CLI_EXIT=$?
  kill "$WATCHDOG_PID" 2>/dev/null || true
fi

if [ "$CLI_EXIT" -eq 124 ]; then
  echo "⚠️  Gemini CLI timed out after ${CLI_TIMEOUT}s (killed)."
elif [ "$CLI_EXIT" -ne 0 ]; then
  echo "⚠️  Gemini CLI exited with code $CLI_EXIT."
fi

# --- Stop proxy ---
echo "Stopping proxy server..."
kill "$PROXY_PID" 2>/dev/null || true
wait "$PROXY_PID" 2>/dev/null || true

# --- Report ---
echo ""
echo "====== Proxy Logs ======"
cat proxy.log
echo "========================"
echo ""

# Check results
PASS=true
BUG_HIT=false

if grep -q "HTTPS/CONNECT" proxy.log; then
  echo "✅ PROXY: Traffic was routed through the local proxy."
else
  echo "❌ PROXY: No HTTPS traffic was intercepted."
  PASS=false
fi

if grep -q "HttpsProxyAgent is not a constructor" proxy.log 2>/dev/null; then
  echo "❌ BUG:   HttpsProxyAgent constructor error detected (issue #24471)"
  BUG_HIT=true
fi

if [ -f "./tmp/hello.py" ]; then
  echo "✅ OUTPUT: Fibonacci script generated at ./tmp/hello.py"
  echo "--- File contents ---"
  cat ./tmp/hello.py
  echo "---------------------"
else
  echo "⚠️  OUTPUT: Fibonacci script was not created."
  if [ "$BUG_HIT" = true ]; then
    echo "   ↳ Caused by upstream Gemini CLI proxy bug (github.com/google-gemini/gemini-cli/issues/24471)"
  elif [ "$CLI_EXIT" -ne 0 ]; then
    echo "   ↳ CLI exited with error code $CLI_EXIT"
  fi
fi

echo ""
echo "====== Summary ======"
echo "Auth mode:    $AUTH_MODE"
echo "CLI exit:     $CLI_EXIT"
echo "Bug #24471:   $([ "$BUG_HIT" = true ] && echo 'YES — reproduced' || echo 'No')"
echo "File created: $([ -f './tmp/hello.py' ] && echo 'YES' || echo 'No')"
echo "====================="
echo ""

if [ "$PASS" = true ]; then
  echo "Test completed. See results above."
else
  exit 1
fi
