WORKFLOW     := GitHub.alfredworkflow
REPO         := grigoriev/alfred-github-workflow
UPDATER_REPO := grigoriev/alfred-workflow-updater
UPDATER_URL  := https://github.com/$(UPDATER_REPO)/releases/latest/download/updater.tar.gz
SCRIPTS      := src/gh.sh src/config.sh src/github.sh src/database.sh src/cache.sh src/globals.sh
EXCLUDES     := '.git/*' '.github/*' '.gitignore' 'Makefile' '$(WORKFLOW)'

# Lint and coverage tools, pinned by digest. Renovate keeps them current.
# renovate: datasource=docker depName=koalaman/shellcheck
SHELLCHECK_IMAGE ?= koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d
# renovate: datasource=docker depName=kcov/kcov
KCOV_IMAGE       ?= kcov/kcov:latest@sha256:481289ae32e55e5b733019515acd10948a4f76dfed381765577db909664fc603

# ShellCheck runs in its pinned image. `make lint SHELLCHECK=shellcheck` uses a
# local one instead.
SHELLCHECK ?= docker run --rm -v "$(CURDIR):/mnt" -w /mnt $(SHELLCHECK_IMAGE)

.PHONY: all build updater verify-updater test coverage lint icons clean \
	print-artifact print-release-files print-provenance print-version set-version

all: build

# Regenerate PNG icons from Octicons (macOS only; see .github/build-icons.sh)
icons:
	bash .github/build-icons.sh

# Fetch the shared updater bundle at build time (not stored in git).
# CHECK_PROVENANCE=1 verifies its signed build provenance first; release.yml
# sets it, so a release bundles only an updater built by its release workflow.
updater:
	@tmp=$$(mktemp -d) && \
	curl -sfL -o "$$tmp/updater.tar.gz" $(UPDATER_URL) && \
	{ [ "$(CHECK_PROVENANCE)" != 1 ] || \
	  { gh attestation verify "$$tmp/updater.tar.gz" --repo $(UPDATER_REPO) && \
	    echo "updater provenance verified"; }; } && \
	tar -xzf "$$tmp/updater.tar.gz" -C src; \
	rc=$$?; rm -rf "$$tmp"; exit $$rc
	chmod +x src/update.sh src/autoupdate.sh

# Smoke-test the fetched updater. Tolerant before the first release exists:
# it reports an update only once a newer release is published.
verify-updater: updater
	@out=$$(alfred_workflow_version=0.0.1 update_repo=$(REPO) update_asset=$(WORKFLOW) bash src/update.sh 2>/dev/null || true); \
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

# Tests need the shared autoupdate.sh, so fetch the updater bundle first
test: updater
	bats tests

# Run the tests under kcov, as the CI sonar job does, and convert the report
# for SonarCloud. kcov needs Linux, so it runs in its container. A failing
# test fails the target.
coverage: updater
	docker run --rm -v "$(CURDIR):$(CURDIR)" -w "$(CURDIR)" $(KCOV_IMAGE) bash -c \
		"apt-get update -qq && apt-get install -y -qq bats jq >/dev/null && kcov --include-pattern=src/ coverage bats tests"
	python3 .github/coverage-to-sonar.py coverage sonar-coverage.xml

lint:
	$(SHELLCHECK) -x --severity=warning $(SCRIPTS)

# Names the CI and release workflows publish.
print-artifact print-release-files:
	@echo $(WORKFLOW)

print-provenance:
	@echo $(WORKFLOW).intoto.jsonl

# The version lives in info.plist. bump-version.yml and release.yml use these.
print-version:
	@python3 -c "import plistlib; print(plistlib.load(open('info.plist', 'rb'))['version'])"

# make set-version VERSION=X.Y.Z; make passes VERSION to the recipe environment
set-version:
	@printf '%s' "$$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || \
		{ echo "usage: make set-version VERSION=X.Y.Z" >&2; exit 1; }
	@python3 -c "import os, plistlib; p = 'info.plist'; d = plistlib.load(open(p, 'rb')); d['version'] = os.environ['VERSION']; plistlib.dump(d, open(p, 'wb'))"
	@echo "info.plist version set to $$VERSION"

clean:
	rm -rf $(WORKFLOW) src/update.sh src/autoupdate.sh coverage sonar-coverage.xml
