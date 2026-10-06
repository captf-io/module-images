# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Builds and checks every CAPTF module image. `make help` lists the targets.
#
# images.json lists the images and their build values; sources/versions.tf
# pins the module release each one is built from. The module code and its
# checks (fmt, validate, unit tests, tflint, tfcapi-lint module, trivy) live
# in the terraform-<provider>-<role> repositories; this repository checks
# the images.
#
# The host needs make, git, podman (or docker with ENGINE=docker), jq and Go
# (for tfcapi-lint). Every other tool runs in a container pinned by digest.

SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.NOTPARALLEL:

# ---- Variables: override on the command line, e.g.
# `make test CLOUDS=aws RUNTIMES=opentofu` or `make test IMAGES=noop-machine`.

REGISTRY ?= ghcr.io/captf-io/module-images
ENGINE ?= podman
RUNTIMES ?= terraform opentofu
# CLOUDS narrows IMAGES to <cloud>-*; IMAGES names images outright.
CLOUDS ?=
IMAGES ?= $(shell hack/images.sh list $(CLOUDS))
# A directory of terraform-<provider>-<role> checkouts (e.g. `..`): build
# from their working trees instead of the pinned releases (hack/fetch.sh).
LOCAL_MODULES ?=

# tfcapi-lint is built from the provider repository (public; CI checks it out
# into .cache/provider). TFCAPI_LINT names a ready binary instead. Without
# either, the image lint in `make test` skips.
PROVIDER_DIR ?= ../cluster-api-provider-terraform
TFCAPI_LINT ?=
TFCAPI_LINT_BIN := .tools/bin/tfcapi-lint

TRIVY_IMAGE := docker.io/aquasec/trivy:0.75.0@sha256:af6acf9a6b85dfe389a1941505c0ce9efef52a4719635e1a962f022a3d855daa
SHELLCHECK_IMAGE := docker.io/koalaman/shellcheck-alpine:v0.11.0@sha256:9955be09ea7f0dbf7ae942ac1f2094355bb30d96fffba0ec09f5432207544002
LICENSE_EYE_IMAGE := docker.io/apache/skywalking-eyes:0.9.0@sha256:cd89ccbbcba2e87d3fb0e34b156b1da208d6c5ac1ada4e2d335e920022c765b8

ifeq ($(ENGINE),docker)
USER_FLAGS := --user $(shell id -u):$(shell id -g)
else
USER_FLAGS := --userns=keep-id --user $(shell id -u):$(shell id -g)
endif
# A container with the repository at /work, as the host user.
CONTAINER = $(ENGINE) run --rm $(USER_FLAGS) --security-opt label=disable \
	-e HOME=/tmp -v "$(CURDIR):/work" -w /work

export ENGINE REGISTRY LOCAL_MODULES

# Build $(TFCAPI_LINT_BIN) from the provider repository unless TFCAPI_LINT is
# set; leave `bin` empty when neither is available.
define RESOLVE_TFCAPI_LINT
bin='$(TFCAPI_LINT)'; \
if [ -z "$$bin" ] && [ -d '$(PROVIDER_DIR)/cmd/tfcapi-lint' ]; then \
	mkdir -p .tools/bin; \
	(cd '$(PROVIDER_DIR)' && go build -o '$(CURDIR)/$(TFCAPI_LINT_BIN)' ./cmd/tfcapi-lint); \
	bin='$(CURDIR)/$(TFCAPI_LINT_BIN)'; \
fi
endef

.PHONY: help fetch lock build test check-images check-headers fix-headers \
	shellcheck scan verify clean

help: ## Show targets.
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "%-14s %s\n", $$1, $$2}'
	@echo
	@echo "IMAGES=$(IMAGES)"
	@echo "RUNTIMES=$(RUNTIMES) ENGINE=$(ENGINE)"

fetch: ## Put each image's pinned module release into build/src/<image> (hack/fetch.sh).
	@hack/fetch.sh $(IMAGES)

lock: fetch ## Regenerate locks/<runtime>/<image>.terraform.lock.hcl (linux_amd64, linux_arm64, darwin_arm64).
	@for rt in $(RUNTIMES); do hack/lock.sh "$$rt" $(IMAGES); done

build: fetch ## Build $(REGISTRY)/<image>:<module tag>-<runtime> for the host platform.
	@for rt in $(RUNTIMES); do for img in $(IMAGES); do \
		hack/build.sh build "$$rt" "$$img"; \
	done; done

test: build ## Build, then smoke-test every image the way the runner runs it, and lint it with tfcapi-lint.
	@$(RESOLVE_TFCAPI_LINT); \
	if [ -z "$$bin" ]; then echo "test: SKIP tfcapi-lint image lint: no TFCAPI_LINT and no $(PROVIDER_DIR)"; fi; \
	for rt in $(RUNTIMES); do for img in $(IMAGES); do \
		TFCAPI_LINT="$$bin" hack/build.sh smoke "$$rt" "$$img"; \
	done; done

check-images: ## images.json, sources/versions.tf and locks/ agree (hack/images.sh check).
	@hack/images.sh check

check-headers: ## Fail on any source file without the Apache-2.0 license header (.licenserc.yaml).
	@$(CONTAINER) "$(LICENSE_EYE_IMAGE)" header check

fix-headers: ## Add the Apache-2.0 license header to every source file missing it.
	@$(CONTAINER) "$(LICENSE_EYE_IMAGE)" header fix

shellcheck: ## shellcheck over hack/*.sh and test/*.sh.
	@mapfile -d '' files < <(find hack test -maxdepth 1 -type f -name '*.sh' -print0 | sort -z); \
	$(ENGINE) run --rm --security-opt label=disable -v "$(CURDIR):/work:ro" -w /work \
		"$(SHELLCHECK_IMAGE)" shellcheck --external-sources "$${files[@]}"; \
	echo "shellcheck: ok ($${#files[@]} files)"

scan: ## trivy config over the Dockerfiles; ignores live in .trivyignore.yaml.
	@mkdir -p .cache/trivy; \
	$(CONTAINER) -e TRIVY_CACHE_DIR=/work/.cache/trivy "$(TRIVY_IMAGE)" config \
		--exit-code 1 --severity MEDIUM,HIGH,CRITICAL \
		--ignorefile .trivyignore.yaml \
		--skip-dirs build --skip-dirs .cache --skip-dirs .tools --skip-dirs sources \
		--skip-dirs test/roots .

verify: check-images check-headers shellcheck scan ## The static checks: everything above but build and test.
	@echo "verify: ok"

clean: ## Remove build/ (fetched modules, stages). Keeps .cache/ (providers) and .tools/.
	@d='$(CURDIR)/build'; \
	if [ -d "$$d" ] && [ ! -L "$$d" ] && [ -f '$(CURDIR)/Makefile' ] && [ "$$d" = "$$(cd '$(CURDIR)' && pwd -P)/build" ]; then \
		echo "clean: removing $$d"; rm -rf -- "$$d"; \
	else \
		echo "clean: no build/ to remove"; \
	fi

print-%: ## Print a variable, e.g. `make print-IMAGES`.
	@printf '%s\n' '$($*)'
