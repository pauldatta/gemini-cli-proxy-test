#!/bin/bash

echo "Starting proxy server..."
node proxy.js > proxy.log 2>&1 &
PROXY_PID=$!

sleep 2

echo "Running Gemini CLI with proxy..."
# Piping input usually forces a CLI into headless/non-interactive mode
echo "Reply with 'OK'" | HTTPS_PROXY="http://127.0.0.1:8080" HTTP_PROXY="http://127.0.0.1:8080" gemini

echo "Stopping proxy server..."
kill $PROXY_PID

echo "--- Proxy Logs ---"
cat proxy.log
echo "------------------"

if grep -q "HTTPS/CONNECT" proxy.log; then
  echo "✅ Success! Traffic was routed through the local proxy."
else
  echo "❌ Failed. No HTTPS traffic was intercepted by the proxy."
  exit 1
fi
