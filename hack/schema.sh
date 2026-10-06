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

# Print the value of the io.captf.variables-schema label of one image: the
# compact JSON Schema `tfcapi-lint schema` derives from the fetched module in
# build/src/<image> (run `make fetch` first). hack/build.sh and the publish
# job pass it to the build with --label.
#
# Usage: hack/schema.sh <image>
# Env:   TFCAPI_LINT (path to tfcapi-lint, required)
set -euo pipefail

usage="usage: schema.sh <image>"
name=${1:?$usage}
lint=${TFCAPI_LINT:-}
[[ -n $lint && -x $lint ]] || { echo "schema.sh: TFCAPI_LINT must name an executable tfcapi-lint" >&2; exit 2; }

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
[[ -f build/src/$name/versions.tf ]] || { echo "schema.sh: build/src/$name is empty; run 'make fetch'" >&2; exit 1; }

role=$(hack/images.sh env "$name" | sed -n 's/^role=//p')
[[ -n $role ]] || { echo "schema.sh: no role for image '$name'" >&2; exit 1; }
"$lint" schema --role "$role" "build/src/$name"
