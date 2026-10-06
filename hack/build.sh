#!/usr/bin/env bash
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

# Build one image for the host platform, or smoke-test the one built, with
# the values images.json and sources/versions.tf give it. The image is tagged
# <registry>/<image>:<module tag>-<runtime>, e.g. aws-machine:v0.1.0-opentofu,
# or <registry>/<image>:local-<runtime> when built from LOCAL_MODULES. The
# Makefile calls this; the publish job builds with the same values.
#
# Usage: hack/build.sh <build|smoke> <terraform|opentofu> <image>
# Env:   ENGINE (podman|docker, default podman), REGISTRY (default
#        ghcr.io/captf-io/module-images), LOCAL_MODULES (see hack/fetch.sh),
#        TFCAPI_LINT (path to tfcapi-lint: build derives the
#        io.captf.variables-schema label from the module with it, smoke
#        passes it to test/smoke.sh), REQUIRE_SCHEMA (1: fail a build that
#        has no tfcapi-lint instead of leaving the label off)
set -euo pipefail

usage="usage: build.sh <build|smoke> <terraform|opentofu> <image>"
action=${1:?$usage}
runtime=${2:?$usage}
name=${3:?$usage}
engine=${ENGINE:-podman}
registry=${REGISTRY:-ghcr.io/captf-io/module-images}

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

case $runtime in terraform | opentofu) ;; *) echo "$usage" >&2; exit 2 ;; esac

declare -A v=()
while IFS='=' read -r key value; do v[$key]=$value; done < <(hack/images.sh env "$name")

if [[ -n ${LOCAL_MODULES:-} ]]; then
  ref="$registry/$name:local-$runtime"
else
  ref="$registry/$name:${v[tag]}-$runtime"
fi

case $action in
  build)
    [[ -f build/src/$name/versions.tf ]] || { echo "build.sh: build/src/$name is empty; run 'make fetch'" >&2; exit 1; }
    args=(--build-arg "IMAGE=$name" --build-arg "ROLE=${v[role]}" --target "${v[role]}"
      --build-arg "IMAGE_VERSION=${v[tag]}" --build-arg "IMAGE_URL=https://github.com/${v[repo]}")
    if [[ -n ${v[capacity]} ]]; then
      args+=(--label "io.captf.capacity=${v[capacity]}"
        --label "io.captf.node-info={\"architecture\":\"${v[arch]}\",\"operatingSystem\":\"linux\"}")
    fi
    if [[ -n ${TFCAPI_LINT:-} ]]; then
      args+=(--label "io.captf.variables-schema=$(TFCAPI_LINT=$TFCAPI_LINT hack/schema.sh "$name")")
    elif [[ ${REQUIRE_SCHEMA:-} == 1 ]]; then
      echo "build.sh: REQUIRE_SCHEMA=1 but TFCAPI_LINT is not set" >&2
      exit 1
    else
      echo "build: WARNING: no tfcapi-lint, so $ref gets no io.captf.variables-schema label" >&2
    fi
    echo "build: $ref ($(<"build/src/$name.ref"))"
    "$engine" build -f "Dockerfile.$runtime" "${args[@]}" -t "$ref" .
    ;;
  smoke)
    MACHINE_LABELS=$([[ -n ${v[capacity]} ]] && echo required || echo absent) \
      MACHINE_ARCH=${v[arch]} TFCAPI_LINT_ALLOW=${v[allow]} SMOKE_ROOT=${v[smoke_root]} \
      ENGINE=$engine TFCAPI_LINT=${TFCAPI_LINT:-} \
      test/smoke.sh "$ref" "${v[role]}" "$runtime"
    ;;
  *) echo "$usage" >&2; exit 2 ;;
esac
