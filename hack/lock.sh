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

# Write locks/<runtime>/<image>.terraform.lock.hcl for the module in
# build/src/<image> (run `make fetch` first), with the hashes of linux_amd64,
# linux_arm64 and darwin_arm64. It runs `providers lock` in the pinned base
# image of Dockerfile.<runtime>, on a copy of the module in build/stage/.
# Provider downloads are cached under .cache/plugins/<runtime>.
#
# Usage: hack/lock.sh <terraform|opentofu> <image>...
# Env:   ENGINE (podman|docker, default podman)
set -euo pipefail

usage="usage: lock.sh <terraform|opentofu> <image>..."
runtime=${1:?$usage}
shift
[[ $# -gt 0 ]] || { echo "$usage" >&2; exit 2; }

engine=${ENGINE:-podman}
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

case $runtime in
  terraform) bin=terraform ;;
  opentofu) bin=tofu ;;
  *) echo "$usage" >&2; exit 2 ;;
esac

image=$(sed -n 's/^FROM \(--platform=[^ ]* \)\{0,1\}\([^ ]*\) AS mirror$/\2/p' "Dockerfile.$runtime")
[[ -n $image ]] || { echo "lock.sh: no 'FROM ... AS mirror' line in Dockerfile.$runtime" >&2; exit 1; }

case $engine in
  docker) user_flags=(--user "$(id -u):$(id -g)") ;;
  # The base sets USER 65532, which wins over keep-id's default, so the user
  # is explicit; keep-id maps it to the host user for file ownership.
  *) user_flags=(--userns=keep-id --user "$(id -u):$(id -g)") ;;
esac

mkdir -p ".cache/plugins/$runtime" "locks/$runtime"
for name in "$@"; do
  src=build/src/$name
  [[ -f $src/versions.tf ]] || { echo "lock.sh: $src/versions.tf not found; run 'make fetch IMAGES=$name'" >&2; exit 1; }
  stage=build/stage/$runtime/$name
  case $stage in build/stage/*/[a-z0-9]*-*) ;; *) echo "lock.sh: refusing to stage into '$stage'" >&2; exit 1 ;; esac
  if [[ -e $stage ]]; then
    [[ -d $stage && ! -L $stage ]] || { echo "lock.sh: $stage is not a directory" >&2; exit 1; }
    rm -rf -- "$stage"
  fi
  mkdir -p "$stage"
  cp -R "$src/." "$stage/"

  echo "--- lock: $name on $runtime (${image%%@*})"
  "$engine" run --rm "${user_flags[@]}" --security-opt label=disable \
    -e HOME=/tmp -e CHECKPOINT_DISABLE=1 -e TF_IN_AUTOMATION=1 -e TF_INPUT=0 \
    -e "TF_PLUGIN_CACHE_DIR=/work/.cache/plugins/$runtime" \
    -v "$root:/work" -w "/work/$stage" --entrypoint /bin/sh "$image" -euc \
    "$bin get -no-color >/dev/null && $bin providers lock -no-color -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_arm64"

  out=locks/$runtime/$name.terraform.lock.hcl
  if [[ -f $stage/.terraform.lock.hcl ]]; then
    cp -- "$stage/.terraform.lock.hcl" "$out"
  else
    # A module that requires no providers gets no lock file from `providers
    # lock`. Write one without providers, so every image has one and the
    # Dockerfiles need no special case.
    printf '%s\n' \
      "# This file is maintained automatically by \"$bin init\"." \
      "# Manual edits may be lost in future updates." >"$out"
  fi
  echo "wrote $out"
done
