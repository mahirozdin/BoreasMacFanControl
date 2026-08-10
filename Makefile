# Boreas — command surface
# Source: blueprint §16.1
# All gates live under scripts/gates/ and can be run directly.

SHELL := /bin/bash
.DEFAULT_GOAL := help

GATES := scripts/gates

# ---------------------------------------------------------------- help

.PHONY: help
help: ## Show this list
	@echo "Boreas — available targets:"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------- gates

.PHONY: next
next: ## Show the next actionable atomic task (skips manual blockers)
	@scripts/next-task.py

.PHONY: check
check: gate-names gate-language blueprint-check docs-check gate-layers gate-deps gate-privacy gate-i18n gate-a11y gate-daemon gate-coverage ## Run every gate
	@echo ""
	@echo "✓ All gates completed."

.PHONY: gate-names
gate-names: ## H1/Y5/Y6 — third party product name and comparative marketing scan
	@$(GATES)/check-names.sh

.PHONY: blueprint-check
blueprint-check: ## Is the frozen blueprint copy untouched
	@$(GATES)/check-blueprint.sh

.PHONY: docs-check
docs-check: ## Broken links, traceability matrix targets, ADR sync
	@$(GATES)/check-docs.sh

.PHONY: gate-layers
gate-layers: ## M1/M2 — Core layer purity and Mock coverage
	@$(GATES)/check-layers.sh

.PHONY: gate-deps
gate-deps: ## T4/H5 — zero dependency rule and licence compatibility
	@$(GATES)/check-deps.sh

.PHONY: gate-privacy
gate-privacy: ## P1/P2 — telemetry SDKs and unexpected network use
	@$(GATES)/check-privacy.sh

.PHONY: gate-i18n
## strings: rebuild the String Catalog from the compiler's own extraction
strings:
	@python3 scripts/build-string-catalog.py

## strings-check: fail if the catalogue is out of date with the source
strings-check:
	@python3 scripts/build-string-catalog.py --check

gate-i18n: ## Y1/Y2/Y4 — hard coded text, comments, completeness, translation origin
	@$(GATES)/check-i18n.sh

.PHONY: gate-a11y
gate-a11y: ## Accessibility — SF Symbol names, chart labels, Reduce Motion
	@$(GATES)/check-a11y.sh

.PHONY: gate-daemon
gate-daemon: ## M4/M5/M6 — daemon XPC surface limits
	@$(GATES)/check-daemon.sh

.PHONY: gate-language
gate-language: ## The repository is written in English
	@$(GATES)/check-language.sh

.PHONY: gate-coverage
gate-coverage: ## Core line coverage >= 85% (blocking)
	@$(GATES)/check-coverage.sh

.PHONY: bootstrap
bootstrap: ## Set up and verify the local development environment
	@scripts/bootstrap.sh

.PHONY: smoke
smoke: ## Hardware smoke test on this Mac (see --with-sleep for the attended leg)
	@scripts/smoke-test-hardware.sh

.PHONY: layout
layout: ## Y3 — pseudo-locale overflow check (needs the app built)
	@scripts/layout-test.sh

.PHONY: cli-test
cli-test: ## Every boreas command, against real state (needs the CLI built)
	@scripts/cli-test.sh

.PHONY: generate
generate: ## Generate the Xcode project from project.yml
	@command -v xcodegen >/dev/null 2>&1 \
		|| { echo "✗ xcodegen missing. Run 'brew install xcodegen'."; exit 1; }
	@xcodegen generate

PACKAGES := Core SharedIPC HardwareKit

# ----------------------------------------------------------------------------
# FAKE GATE, found in P7.01 — READ THIS BEFORE TOUCHING THE TWO TARGETS BELOW.
#
# Both used to pipe into `tail`:
#
#   ( cd Packages/$$p && swift test 2>&1 | grep … | tail -1 ) || exit 1
#
# A subshell's exit status is the status of the LAST command in the pipeline,
# and `tail` always succeeds. So `swift test`'s status was discarded and
# `make test` exited 0 **with failing tests** — proven by breaking a test on
# purpose and watching the target come back green. CI runs `make test`, so a
# failing test would not have broken the build.
#
# It also explains the `HardwareKit error: fatalError` that the P6.10 run log
# recorded as unexplained: the same `grep | tail` surfaces a stderr line from an
# otherwise-passing run and prints it where the result belongs.
#
# The output is captured first and the status kept explicitly. Do not
# reintroduce a pipeline here — and note the note fifteen lines below, where the
# same mistake was already found once in `make lint`.
#
# **On failure the FULL captured output is printed**, not the filtered tail. That
# is P7.12's doing: the intermittent `HardwareKit error: fatalError` has now
# happened three times across three sessions and every time the `grep` threw away
# the only evidence that could have explained it. A summary line is for a passing
# run; a failing one gets everything.
# ----------------------------------------------------------------------------

.PHONY: build
build: ## Build all SPM packages
	@for p in $(PACKAGES); do \
		printf '  %-12s ' "$$p"; \
		out=$$( cd Packages/$$p && swift build 2>&1 ); status=$$?; \
		printf '%s\n' "$$out" | tail -1; \
		if [ $$status -ne 0 ]; then echo "  ✗ $$p failed to build"; exit 1; fi; \
	done

.PHONY: test
test: ## Run all tests
	@for p in $(PACKAGES); do \
		if [ -d "Packages/$$p/Tests" ]; then \
			printf '  %-12s ' "$$p"; \
			out=$$( cd Packages/$$p && swift test 2>&1 ); status=$$?; \
			printf '%s\n' "$$out" | grep -E 'Test run with|error:' | tail -1; \
			if [ $$status -ne 0 ]; then \
				echo "  ✗ $$p tests failed — full output follows"; \
				printf '%s\n' "$$out" | sed 's/^/      /'; \
				exit 1; \
			fi; \
		fi; \
	done

# NOTE: the '|| echo ✓' that used to sit here was a FAKE GATE — swift format
# found real violations and exited while the message said "nothing to scan"
# and the gate looked green. Existing directories are collected explicitly
# and the exit code is no longer swallowed.
FORMAT_DIRS := $(shell for d in Packages App Daemon CLI Widget; do [ -d "$$d" ] && echo "$$d"; done)

.PHONY: lint
lint: ## SwiftLint + swift format check (writes nothing)
	@command -v swiftlint >/dev/null 2>&1 || { echo "✗ swiftlint missing — brew bundle"; exit 1; }
	@swiftlint lint --quiet --strict && echo "  ✓ swiftlint"
	@if [ -n "$(FORMAT_DIRS)" ]; then \
		swift format lint --recursive --strict $(FORMAT_DIRS) && echo "  ✓ swift format"; \
	else \
		echo "  ○ swift format: no directories to scan"; \
	fi

.PHONY: format
format: ## Format with swift format (MODIFIES files)
	@if [ -n "$(FORMAT_DIRS)" ]; then \
		swift format --in-place --recursive $(FORMAT_DIRS) && echo "  ✓ formatted"; \
	fi

.PHONY: release
release: ## Sign, notarize, build the DMG
	@echo "Activates in P8 (see TODO.md)"

.PHONY: clean
clean: ## Remove build outputs
	@rm -rf .build build dist DerivedData .gate-tmp
	@echo "✓ Cleaned."
