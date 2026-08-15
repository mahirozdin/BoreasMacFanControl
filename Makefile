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

# ---------------------------------------------------------------------------
# P7.15 — CI ran red for 27 consecutive pushes and nothing said so. Every run
# log from P4 onward recorded `make check` green, which it was; nobody looked
# at the remote, because nothing ever asked. This is what asks.
#
# Deliberately NOT part of `make check`: gates must run offline and must not go
# red because of a remote this machine cannot reach. It belongs to the BOOT.md
# snapshot instead, where "if anything is red, fix that first" already applies.
# A missing or unauthenticated `gh` skips rather than fails — punishing an
# environment without it would teach people to ignore the check.
# ---------------------------------------------------------------------------
.PHONY: ci-status
ci-status: ## The latest CI run's conclusion — a failed run exits non-zero
	@command -v gh >/dev/null 2>&1 \
		|| { echo "○ SKIP: gh not installed — CI status unknown"; exit 0; }
	@gh auth status >/dev/null 2>&1 \
		|| { echo "○ SKIP: gh not authenticated — CI status unknown"; exit 0; }
	@LINE=$$(gh run list --limit 1 \
		--json status,conclusion,displayTitle,url \
		-q '.[] | "\(.status)\t\(.conclusion)\t\(.displayTitle)\t\(.url)"' 2>/dev/null); \
	if [ -z "$$LINE" ]; then echo "○ SKIP: no CI run found"; exit 0; fi; \
	STATE=$$(printf '%s' "$$LINE" | cut -f1); \
	RESULT=$$(printf '%s' "$$LINE" | cut -f2); \
	TITLE=$$(printf '%s' "$$LINE" | cut -f3); \
	URL=$$(printf '%s' "$$LINE" | cut -f4); \
	if [ "$$STATE" != "completed" ]; then \
		echo "◍ CI $$STATE — $$TITLE"; echo "    $$URL"; \
	elif [ "$$RESULT" = "success" ]; then \
		echo "✓ CI green — $$TITLE"; \
	else \
		echo "✗ CI $$RESULT — $$TITLE"; echo "    $$URL"; exit 1; \
	fi

# ---------------------------------------------------------------------------
# P8.09 — the eight release gates in ARCHITECTURE.md §10.
#
# Not part of `make check`: three of the eight cannot be answered by a script
# at all, and a target that always reports incomplete has no business in the
# gate suite every commit runs.
# ---------------------------------------------------------------------------
.PHONY: release-gates
release-gates: ## ARCHITECTURE.md §10 — every gate a release must clear
	@scripts/release-gates.sh

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

.PHONY: icon
icon: ## Rebuild App/Resources/Boreas.icns from the icon source (needs imagemagick)
	@scripts/make-icon.sh

.PHONY: dmg-background
dmg-background: ## Rebuild the disk image background art (needs imagemagick)
	@scripts/make-dmg-background.sh

.PHONY: dmg-layout
dmg-layout: ## Re-bake the disk image window layout — MAINTAINER ONLY, needs dmgbuild
	@scripts/make-dmg-layout.sh

.PHONY: social-card
social-card: ## Rebuild the repository's link preview card (needs imagemagick)
	@scripts/make-social-card.sh

.PHONY: screenshots
screenshots: ## Re-render the pictures the READMEs show (needs the app built)
	@scripts/make-screenshots.sh

.PHONY: demo
demo: ## Re-encode the README's demo loop (needs the app built + imagemagick)
	@scripts/make-demo.sh

.PHONY: generate
generate: ## Generate the Xcode project from project.yml
	@command -v xcodegen >/dev/null 2>&1 \
		|| { echo "✗ xcodegen missing. Run 'brew install xcodegen'."; exit 1; }
	@# project.yml names Local.xcconfig as the config file for BOTH
	@# configurations, and that file is git ignored because it carries a team
	@# identifier. XcodeGen refuses a spec whose config file is absent, so a
	@# fresh clone could not generate at all — which is what had CI red from
	@# 2026-08-04 (the commit that introduced signing) until P7.15 found it.
	@# Seeding from the committed example makes an unsigned build the default
	@# instead of a hard failure, which is the state ADR 0019 already describes.
	@# Announced rather than silent: a developer must know an empty team
	@# identifier is why the privileged helper will not run.
	@if [ ! -f Local.xcconfig ]; then \
		cp Local.xcconfig.example Local.xcconfig; \
		echo "→ Local.xcconfig created from the example — unsigned build."; \
		echo "  Fill in DEVELOPMENT_TEAM to build the privileged helper (ADR 0019)."; \
	fi
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
# Same treatment as `test` below, and it needed it more (P7.12): this took
# `tail -1` of the raw output, which on a failed build is SwiftPM's `error:
# fatalError` trailer — and then printed **no** output at all, so a broken
# build said only "fatalError" and "failed to build". P7.03 gave `test` its
# full-output branch; `build` never got one.
build: ## Build all SPM packages
	@for p in $(PACKAGES); do \
		printf '  %-12s ' "$$p"; \
		out=$$( cd Packages/$$p && swift build 2>&1 ); status=$$?; \
		line=$$(printf '%s\n' "$$out" | grep -E ':[0-9]+:[0-9]+: error:' | head -1); \
		[ -n "$$line" ] || line=$$(printf '%s\n' "$$out" | tail -1); \
		printf '%s\n' "$$line"; \
		if [ $$status -ne 0 ]; then \
			echo "  ✗ $$p failed to build — full output follows"; \
			printf '%s\n' "$$out" | sed 's/^/      /'; \
			exit 1; \
		fi; \
	done

.PHONY: test
# P7.12 — why the summary line used to be useless.
#
# `swift test` ends a FAILED BUILD with the line `error: fatalError`. It is
# SwiftPM's own generic trailer and says nothing; the real diagnostic is above
# it. Taking `grep 'error:' | tail -1` therefore picked the trailer every time,
# which is how six days of `HardwareKit error: fatalError` came to look like a
# runtime crash inside HardwareKit — a hardware path that was searched for
# through P6.10, P7.01, P7.02 and P7.03 and never existed. It means one thing:
# **the package did not build.**
#
# So a real `file:line:col: error:` diagnostic is preferred, the trailer is
# used only when there is nothing better, and the full output still follows on
# failure (P7.03).
test: ## Run all tests
	@for p in $(PACKAGES); do \
		if [ -d "Packages/$$p/Tests" ]; then \
			printf '  %-12s ' "$$p"; \
			out=$$( cd Packages/$$p && swift test 2>&1 ); status=$$?; \
			line=$$(printf '%s\n' "$$out" | grep -E ':[0-9]+:[0-9]+: error:' | head -1); \
			[ -n "$$line" ] || line=$$(printf '%s\n' "$$out" \
				| grep -E 'Test run with|error:' | grep -v 'error: fatalError' | tail -1); \
			[ -n "$$line" ] || line=$$(printf '%s\n' "$$out" \
				| grep -E 'Test run with|error:' | tail -1); \
			printf '%s\n' "$$line"; \
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
