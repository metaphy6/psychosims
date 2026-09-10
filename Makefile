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

.PHONY: help git git.dry track.add track.list roadmap.status doctor scaffold skills.status skills.find codeg test verify
.PHONY: build lint format format.check verify.contracts dart.test dart.contracts dart.lint dart.format dart.format.check
.PHONY: server.build server.test server.lint server.format server.format.check native.build native.test native.contracts native.acceptance
.PHONY: security.secrets security.dependencies security.privacy server.restore server.load server.certified server.integration cost.check

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

## codeg             Initialize or update the CodeGraph index
codeg:
	@$(XOPS)/codegraph_ops.py update

## doctor            Sanity-check the framework is wired correctly
doctor:
	@$(XOPS)/doctor.py

## scaffold          Re-sync framework files from the agentic-workspace source repo
scaffold:
	@echo "xops/init/ is framework-only and not shipped to scaffolded projects."
	@echo "Re-run the scaffolder from the agentic-workspace repo instead:"
	@echo "  /path/to/agentic-workspace/xops/init/scaffold.sh --target $$(pwd) --help"

## skills.status     List all skills with line count, last-modified, and AGENTS.md refs
skills.status:
	@$(XOPS)/skills_ops.py status

## skills.find       Search skills by tag or name keyword (TAG=<tag>)
skills.find:
	@TAG="$(TAG)" $(XOPS)/skills_ops.py find

## test              Run all test suites (xops + project)
NATIVE_TEST_TARGET ?= native.test
DART_TEST_TARGET ?= dart.test
ifneq ($(words $(DART_TEST_TARGET)),1)
$(error DART_TEST_TARGET must be dart.test or dart.contracts)
endif
ifneq ($(filter-out dart.test dart.contracts,$(DART_TEST_TARGET)),)
$(error DART_TEST_TARGET must be dart.test or dart.contracts)
endif
ifneq ($(words $(NATIVE_TEST_TARGET)),1)
$(error NATIVE_TEST_TARGET must be native.test or native.contracts)
endif
ifneq ($(filter-out native.test native.contracts,$(NATIVE_TEST_TARGET)),)
$(error NATIVE_TEST_TARGET must be native.test or native.contracts)
endif
test:
	@bash xops/test/run_tests.sh
	@$(MAKE) --no-print-directory cost.check
	@$(MAKE) --no-print-directory $(DART_TEST_TARGET)
	@$(MAKE) --no-print-directory server.test
	@$(MAKE) --no-print-directory $(NATIVE_TEST_TARGET)

## verify            Verifier gate: build + lint + format + test + doctor (run cold)
verify:
	@$(MAKE) --no-print-directory build
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory format.check
	@$(MAKE) --no-print-directory test
	@$(MAKE) --no-print-directory doctor

## verify.contracts  CI verification without real model weights; not model acceptance
verify.contracts:
	@$(MAKE) --no-print-directory verify NATIVE_TEST_TARGET=native.contracts DART_TEST_TARGET=dart.contracts

## build             Build all project modules
build:
	@$(MAKE) --no-print-directory native.build
	@$(MAKE) --no-print-directory server.build

## lint              Lint all project modules
lint:
	@scripts/secret_check.sh
	@scripts/env_read_check.sh
	@scripts/no_raw_print_check.sh
	@scripts/check_hardcoded_strings.sh
	@scripts/core_purity_gate.sh
	@scripts/content_integrity_check.sh
	@$(MAKE) --no-print-directory dart.lint
	@$(MAKE) --no-print-directory server.lint

## security.secrets  Real secret scanner acceptance and index/worktree scan
security.secrets:
	@$(PYTHON) -m unittest xops.test.test_security_acceptance.SecretAcceptanceTests
	@scripts/secret_check.sh

## security.dependencies  Check resolved inventory, licenses and vulnerabilities
security.dependencies:
	@$(PYTHON) -m unittest xops.test.test_dependency_inventory xops.test.test_dependency_scan xops.test.test_security_acceptance.DependencyAcceptanceTests
	@scripts/vuln_check.sh

## security.privacy  Exercise client and PostgreSQL durable-data privacy boundaries
security.privacy:
	@scripts/no_transcripts_check.sh

## server.restore    Prove local PostgreSQL backup, restore and replay/revocation recovery
server.restore:
	@bash scripts/local_restore_drill.sh

## server.load       Measure local HTTP/SQL load, admission and executable startup
server.load:
	@bash server/scripts/postgres_test.sh --load

## server.certified  Test trusted cure authorization, rewards and replay on local PostgreSQL
server.certified:
	@bash server/scripts/postgres_test.sh --certified

## server.integration  Exercise held and certified Flutter receipts through local HTTP and PostgreSQL
server.integration:
	@bash server/scripts/postgres_test.sh --flutter

## cost.check        Verify the numeric infrastructure report matches its reviewed assumptions
cost.check:
	@$(PYTHON) scripts/infra_cost_model.py

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

## dart.contracts    Explicit contract profile excluding model acceptance suites
dart.contracts:
	@scripts/dart_test.sh --contracts-only

## dart.lint         Run Dart static analysis
dart.lint:
	@scripts/dart_lint.sh

## dart.format.check Check Dart formatting
dart.format.check:
	@scripts/dart_format.sh --check

## dart.format       Format Dart code
dart.format:
	@scripts/dart_format.sh

## server.test       Run Go server tests
server.test:
	@scripts/server_test.sh

## server.lint       Lint Go server code
server.lint:
	@scripts/server_lint.sh

## server.format.check Check Go formatting
server.format.check:
	@scripts/server_format.sh --check

## server.format     Format Go code
server.format:
	@scripts/server_format.sh

## server.build      Install server dependencies
server.build:
	@scripts/server_build.sh

## native.build      Build the pinned llama.cpp native engine
native.build:
	@scripts/native_build.sh

## native.test       Run native C/C++ tests + ASan/LSan cycle gate
native.test:
	@scripts/native_test.sh
	@scripts/native_sanitizer_test.sh

## native.contracts  Explicit API/stub/sanitizer contracts without model weights
native.contracts:
	@scripts/native_test.sh --contracts-only
	@scripts/native_sanitizer_test.sh --contracts-only

## native.acceptance Strict real-model generation and sanitizer acceptance
native.acceptance: native.test
