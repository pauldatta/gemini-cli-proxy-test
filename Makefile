.PHONY: setup test test-apikey test-workaround clean proxy-check

# Install prerequisites
setup:
	@echo "Checking for Node.js..."
	@command -v node >/dev/null 2>&1 || { echo >&2 "Node.js is required but it's not installed. Please install it first."; exit 1; }
	@echo "Checking for Gemini CLI..."
	@command -v gemini >/dev/null 2>&1 || { echo "Installing Gemini CLI globally..."; npm install -g @google/gemini-cli; }
	@echo "Checking for timeout command (optional, for non-hanging tests)..."
	@command -v gtimeout >/dev/null 2>&1 || command -v timeout >/dev/null 2>&1 || echo "  ⚠️  No timeout command found. Install coreutils (brew install coreutils) for best results."
	@echo "✅ Setup complete."

# Quick check: verify proxy starts and tunnels traffic (no Gemini CLI needed)
proxy-check:
	@echo "Smoke-testing proxy..."
	@node proxy.js > proxy.log 2>&1 & PROXY_PID=$$!; \
	sleep 2; \
	if curl -s -o /dev/null -w "%{http_code}" -x http://127.0.0.1:8080 https://generativelanguage.googleapis.com 2>/dev/null | grep -q "404\|200"; then \
		echo "✅ Proxy is tunneling HTTPS correctly."; \
	else \
		echo "❌ Proxy tunnel failed."; \
	fi; \
	kill $$PROXY_PID 2>/dev/null; \
	cat proxy.log; \
	rm -f proxy.log

# Run the proxy test using OAuth (default auth — reproduces bug #24471)
test:
	@echo "Running proxy test (OAuth mode)..."
	@chmod +x test_proxy.sh
	@./test_proxy.sh oauth

# Run the proxy test using API key auth (workaround — bypasses crashing OAuth path)
# Usage: GEMINI_API_KEY=your_key make test-apikey
test-apikey:
	@if [ -z "$${GEMINI_API_KEY:-}" ]; then \
		echo "❌ Usage: GEMINI_API_KEY=your_key make test-apikey"; \
		echo "   Get a key from https://aistudio.google.com/apikey"; \
		exit 1; \
	fi
	@echo "Running proxy test (API key mode — workaround for #24471)..."
	@chmod +x test_proxy.sh
	@./test_proxy.sh apikey

# Run the proxy test using global-agent with existing OAuth/GCA/Vertex auth (no API key needed)
# This is the enterprise-relevant workaround test.
test-workaround:
	@echo "Running proxy test (global-agent + existing auth — workaround for #24471)..."
	@chmod +x test_proxy.sh
	@./test_proxy.sh workaround

# Clean up log files and generated files
clean:
	@echo "Cleaning up..."
	rm -f proxy.log
	rm -rf ./tmp
