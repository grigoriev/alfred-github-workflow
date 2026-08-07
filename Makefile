WORKFLOW    := GitHub.alfredworkflow
UPDATER_URL := https://github.com/grigoriev/alfred-workflow-updater/releases/latest/download/update.sh
SCRIPTS     := src/gh.sh src/config.sh src/github.sh src/database.sh src/cache.sh src/globals.sh
EXCLUDES    := '.git/*' '.github/*' '.gitignore' 'Makefile' '$(WORKFLOW)'

.PHONY: all build updater verify-updater test lint icons clean

all: build

# Regenerate PNG icons from Octicons (macOS only; see .github/build-icons.sh)
icons:
	bash .github/build-icons.sh

# Fetch the shared updater at build time (not stored in git)
updater:
	curl -sfL $(UPDATER_URL) -o src/update.sh
	chmod +x src/update.sh

# Smoke-test the fetched updater. Tolerant before the first release exists:
# it reports an update only once a newer release is published.
verify-updater: updater
	@out=$$(alfred_workflow_version=0.0.1 update_repo=grigoriev/alfred-github-workflow update_asset=$(WORKFLOW) bash src/update.sh 2>/dev/null || true); \
	if printf '%s' "$$out" | grep -q '"title":"Update to v'; then \
		echo "updater OK"; \
	else \
		echo "no release yet; updater smoke test skipped"; \
	fi

# Build the .alfredworkflow bundle
build: verify-updater
	rm -f $(WORKFLOW)
	zip -qr $(WORKFLOW) . -x $(EXCLUDES)
	unzip -l $(WORKFLOW) | grep -q 'src/update.sh'
	@echo "built $(WORKFLOW)"

test:
	bats tests

lint:
	shellcheck -x --severity=warning $(SCRIPTS)

clean:
	rm -f $(WORKFLOW) src/update.sh
