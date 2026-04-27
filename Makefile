.PHONY: setup test clean

# Install prerequisites
setup:
	@echo "Checking for Node.js..."
	@command -v node >/dev/null 2>&1 || { echo >&2 "Node.js is required but it's not installed. Please install it first."; exit 1; }
	@echo "Installing Gemini CLI globally..."
	npm install -g @google/gemini-cli

# Run the automated proxy test
test:
	@echo "Running proxy test script..."
	chmod +x test_proxy.sh
	./test_proxy.sh

# Clean up log files
clean:
	@echo "Cleaning up..."
	rm -f proxy.log
