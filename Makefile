TEMPDIR = ./.tmp
DISTDIR = ./dist
SNAPSHOTDIR = ./snapshot
PROJECT = syft
MODULE = github.com/anchore/syft
TOOL_DIR = $(TEMPDIR)/bin

# Tool versions
GOLANGCI_LINT_VERSION = v1.55.2
GOSEC_VERSION = v2.18.2

# Formatting variables
BOLD := $(shell tput -T linux bold)
PURPLE := $(shell tput -T linux setaf 5)
GREEN := $(shell tput -T linux setaf 2)
CYAN := $(shell tput -T linux setaf 6)
RED := $(shell tput -T linux setaf 1)
RESET := $(shell tput -T linux sgr0)
TITLE := $(BOLD)$(PURPLE)
SUCCESS := $(BOLD)$(GREEN)

## Build targets

.PHONY: all
all: clean build test ## Run all build, test targets

.PHONY: build
build: ## Build the project
	$(call title,"Building $(PROJECT)")
	go build -o $(DISTDIR)/$(PROJECT) ./cmd/syft

.PHONY: run
run: ## Run the project
	go run ./cmd/syft

.PHONY: test
test: ## Run unit tests
	$(call title,"Running unit tests")
	# Using -count=1 to disable test caching for more reliable results
	# Using -timeout 120s to avoid hanging tests
	# Increased timeout to 300s for slower machines
	go test -count=1 -race -timeout 300s -coverprofile=coverage.txt -covermode=atomic ./...

.PHONY: integration
integration: ## Run integration tests
	$(call title,"Running integration tests")
	go test -v -tags integration ./test/integration/...

.PHONY: lint
lint: $(TOOL_DIR)/golangci-lint ## Run linting
	$(call title,"Running linting")
	$(TOOL_DIR)/golangci-lint run --timeout 5m

.PHONY: lint-fix
lint-fix: $(TOOL_DIR)/golangci-lint ## Auto-fix lint issues
	$(TOOL_DIR)/golangci-lint run --fix

.PHONY: format
format: ## Format all Go files
	gofmt -w .
	goimports -w .

.PHONY: clean
clean: ## Remove build artifacts
	$(call title,"Cleaning")
	rm -rf $(DISTDIR) $(SNAPSHOTDIR) $(TEMPDIR)

.PHONY: bootstrap
bootstrap: $(TEMPDIR) ## Install project tooling
	$(call title,"Bootstrapping tools")
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)

SNAPSHOT_CMD=$(shell bash -c 'if [[ $$(cat .binny.yaml | grep -c snapshot) -gt 0 ]]; then echo snapshot; else echo build; fi')

.PHONY: snapshot
snapshot: ## Build a snapshot release
	$(call title,"Building snapshot")
	goreleaser release --clean --skip=publish --snapshot

.PHONY: changelog
changelog: ## Generate a changelog
	$(call title,"Generating changelog")
	chronicle --version
	chronicle -x .chronicle.yaml changelog -n --version $(VERSION)

$(TEMPDIR):
	mkdir -p $(TEMPDIR)

$(TOOL_DIR)/golangci-lint: $(TEMPDIR)
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(TOOL_DIR) $(GOLANGCI_LINT_VERSION)

## Helpers

.PHONY: help
help: ## Display this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-25s$(RESET) %s\n", $$1, $$2}'

define title
	@printf '$(TITLE)$(1)$(RESET)\n'
endef
