.PHONY: help shell-files format lint check clean

SHFMT_FLAGS := -i 4 -ci
SHELL_FILES_CMD := ./scripts/list_shell_files.sh

help:
	@echo "Available commands:"
	@echo "  shell-files  - Print discovered shell files"
	@echo "  format       - Format shell and Nushell files (shfmt, nufmt)"
	@echo "  lint         - Check formatting and Nushell parser syntax"
	@echo "  check        - Alias for lint"
	@echo "  clean        - Remove temporary files"

shell-files:
	@$(SHELL_FILES_CMD)

format:
	@echo "Formatting shell files..."
	@files="$$( $(SHELL_FILES_CMD) )"; \
	if [ -z "$$files" ]; then \
		echo "No shell files found."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$files" | xargs shfmt -w $(SHFMT_FLAGS)
	@nu --no-config-file ./scripts/nu-lint.nu format
	@echo "Formatting complete."

lint:
	@echo "Checking shell formatting..."
	@files="$$( $(SHELL_FILES_CMD) )"; \
	if [ -z "$$files" ]; then \
		echo "No shell files found."; \
		exit 0; \
	fi; \
	printf '%s\n' "$$files" | xargs shfmt -d $(SHFMT_FLAGS)
	@nu --no-config-file ./scripts/nu-lint.nu check
	@echo "Formatting and Nushell syntax checks complete."

check: lint

clean:
	@echo "Cleaning up..."
	@find . -name "*.tmp" -delete
	@echo "Clean complete."
