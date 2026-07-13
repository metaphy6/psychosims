# ┊┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃
#  Model-agnostic agent framework Makefile
# ──────────────────────────────────────────────────────────────
#  Targets are thin dispatchers. All real logic lives in
#  xops/makefile/<module>.py (stdlib-only, cross-platform).
#
#  Convention:
#    • daily verbs are short  : help, git, doctor, scaffold
#    • everything else uses   : domain.action  (track.add, git.dry, roadmap.status)
# ┊┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃┃

PYTHON ?= python3
XOPS   := $(PYTHON) xops/makefile

# Tracking append defaults (override on CLI: make track.add ACTION=note SUMMARY="...")
ACTION  ?= note
STATUS  ?= completed
SCOPE   ?= general
AGENT   ?= human
SUMMARY ?=
REFS    ?=
RUN_ID  ?=

# Skills targets
TAG ?=

.DEFAULT_GOAL := help

.PHONY: help git git.dry track.add track.list roadmap.status doctor scaffold skills.status skills.find test verify

## help              List all available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  make /' | sort

## git               Commit pending tracking rows as conventional commits + push
git:
	@$(XOPS)/git_ops.py push

## git.dry           Preview what `make git` would commit and push (read-only)
git.dry:
	@$(XOPS)/git_ops.py dry

## track.add         Append a row to docs/tracking/tracking.csv (vars: ACTION STATUS SCOPE AGENT SUMMARY REFS RUN_ID)
track.add:
	@$(XOPS)/track_ops.py add \
		--action="$(ACTION)" --status="$(STATUS)" --scope="$(SCOPE)" \
		--agent="$(AGENT)"   --summary="$(SUMMARY)" --refs="$(REFS)" \
		$(if $(RUN_ID),--run-id="$(RUN_ID)",)

## track.list        Show recent tracking rows (last 20)
track.list:
	@$(XOPS)/track_ops.py list

## roadmap.status    Summarize ROADMAP.md checkbox progress
roadmap.status:
	@$(XOPS)/roadmap_ops.py status

## doctor            Sanity-check the framework is wired correctly
doctor:
	@$(XOPS)/doctor.py

## scaffold          Print bootstrapper usage (run xops/init/scaffold.sh --help for real)
scaffold:
	@xops/init/scaffold.sh --help

## skills.status     List all skills with line count, last-modified, and AGENTS.md refs
skills.status:
	@$(XOPS)/skills_ops.py status

## skills.find       Search skills by tag or name keyword (TAG=<tag>)
skills.find:
	@TAG="$(TAG)" $(XOPS)/skills_ops.py find

## test              Run all test suites (xops + project)
test:
	@bash xops/test/run_tests.sh
	@$(MAKE) --no-print-directory dart.test
	@$(MAKE) --no-print-directory server.test
	@$(MAKE) --no-print-directory native.test

## verify            Verifier gate: build + lint + format + test + doctor (run cold)
verify:
	@$(MAKE) --no-print-directory build
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory format.check
	@$(MAKE) --no-print-directory test
	@$(MAKE) --no-print-directory doctor

## build             Build all project modules
build:
	@$(MAKE) --no-print-directory native.build
	@$(MAKE) --no-print-directory server.build

## lint              Lint all project modules
lint:
	@scripts/env_read_check.sh
	@scripts/no_raw_print_check.sh
	@scripts/check_hardcoded_strings.sh
	@$(MAKE) --no-print-directory dart.lint
	@$(MAKE) --no-print-directory server.lint

## format.check      Check formatting of all project modules
format.check:
	@$(MAKE) --no-print-directory dart.format.check
	@$(MAKE) --no-print-directory server.format.check

## format            Format all project modules
format:
	@$(MAKE) --no-print-directory dart.format
	@$(MAKE) --no-print-directory server.format

## dart.test         Run Dart package tests
dart.test:
	@scripts/dart_test.sh

## dart.lint         Run Dart static analysis
dart.lint:
	@scripts/dart_lint.sh

## dart.format.check Check Dart formatting
dart.format.check:
	@scripts/dart_format.sh --check

## dart.format       Format Dart code
dart.format:
	@scripts/dart_format.sh

## server.test       Run Python server tests
server.test:
	@scripts/server_test.sh

## server.lint       Lint Python server code
server.lint:
	@scripts/server_lint.sh

## server.format.check Check Python formatting
server.format.check:
	@scripts/server_format.sh --check

## server.format     Format Python code
server.format:
	@scripts/server_format.sh

## server.build      Install server dependencies
server.build:
	@scripts/server_build.sh

## native.build      Build native C/C++ stub
native.build:
	@scripts/native_build.sh

## native.test       Run native C/C++ tests + ASan/LSan cycle gate
native.test:
	@scripts/native_test.sh
	@scripts/native_sanitizer_test.sh
