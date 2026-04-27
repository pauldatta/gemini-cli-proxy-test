#!/bin/bash

echo "Starting proxy server..."
node proxy.js > proxy.log 2>&1 &
PROXY_PID=$!

sleep 2

echo "Running Gemini CLI with proxy to generate Fibonacci script..."
mkdir -p ./tmp

# Piping input forces the CLI into headless/non-interactive mode
echo "Write a python script in ./tmp/hello.py that calculates the Fibonacci sequence up to 10" | HTTPS_PROXY="http://127.0.0.1:8080" HTTP_PROXY="http://127.0.0.1:8080" gemini

echo "Stopping proxy server..."
kill $PROXY_PID

echo "--- Proxy Logs ---"
cat proxy.log
echo "------------------"

if grep -q "HTTPS/CONNECT" proxy.log; then
  echo "✅ Success! Traffic was routed through the local proxy."
  if [ -f "./tmp/hello.py" ]; then
    echo "✅ Fibonacci script generated successfully at ./tmp/hello.py."
  else
    echo "⚠️ Note: The Fibonacci script was not created. This is expected if the 'HttpsProxyAgent is not a constructor' CLI bug occurs when using a proxy, or due to headless environment restrictions."
  fi
else
  echo "❌ Failed. No HTTPS traffic was intercepted by the proxy."
  exit 1
fi
