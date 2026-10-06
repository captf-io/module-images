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

# Smoke test for one module image: check its config against the image
# contract, then run the module the way the CAPTF runner does: read-only
# root, network off, providers from the mirror only, and the working
# directory on a tmpfs at /captf/work (exec, like the emptyDir the Job
# mounts; docker's --tmpfs defaults to noexec). init proves the provider
# mirror holds every provider the module requires, and validate proves the
# module loads against the provider schemas. A cloud module stops there: a
# real apply needs cloud credentials. With SMOKE_ROOT, the root module
# SMOKE_ROOT/main.tf.json (which calls /captf/module and sets every contract
# input) is also applied, its outputs printed, and destroyed: the noop
# images provision nothing, so they get the full run.
#
# Usage: test/smoke.sh <image> <role> <terraform|opentofu>
# Env:   ENGINE (podman|docker, default podman),
#        MACHINE_LABELS (required, the default: the machine image must carry
#        io.captf.capacity and io.captf.node-info; absent: it must carry
#        neither, for a module without a default instance shape),
#        MACHINE_ARCH (the architecture the machine image must declare; any
#        of amd64 and arm64 when unset),
#        TFCAPI_LINT (path to tfcapi-lint; run `image --strict` when set),
#        TFCAPI_LINT_ALLOW (the image's allowed warnings, as --allow-warning
#        flags; the Makefile passes them from images.json),
#        SMOKE_ROOT (a directory holding a root main.tf.json: init, validate,
#        apply, output and destroy it instead of init and validate on a copy
#        of the module).
set -euo pipefail

usage="usage: smoke.sh <image> <cluster|machine|machinepool> <terraform|opentofu>"
image=${1:?$usage}
role=${2:?$usage}
runtime=${3:?$usage}
engine=${ENGINE:-podman}
machine_labels=${MACHINE_LABELS:-required}
case $machine_labels in
  required | absent) ;;
  *) echo "smoke.sh: MACHINE_LABELS must be required or absent, not '$machine_labels'" >&2; exit 2 ;;
esac

case $runtime in
  terraform) want_runtime=terraform ;;
  opentofu) want_runtime=tofu ;;
  *) echo "$usage" >&2; exit 2 ;;
esac

fail() { echo "FAIL: $image: $*" >&2; exit 1; }
label() { "$engine" image inspect --format "{{index .Config.Labels \"$1\"}}" "$image"; }

echo "--- $image: image config"
user=$("$engine" image inspect --format '{{.Config.User}}' "$image")
[[ $user == 65532:65532 ]] || fail "user is '$user', want 65532:65532"
[[ $(label io.captf.contract) == v1alpha1 ]] || fail "io.captf.contract"
[[ $(label io.captf.role) == "$role" ]] || fail "io.captf.role is '$(label io.captf.role)', want $role"
[[ $(label io.captf.runtime) == "$want_runtime" ]] || fail "io.captf.runtime"
if [[ $role == machine && $machine_labels == required ]]; then
  capacity=$(label io.captf.capacity)
  node_info=$(label io.captf.node-info)
  [[ -n $capacity ]] || fail "io.captf.capacity missing"
  jq -e 'type == "object" and (.cpu | type == "string") and (.memory | type == "string")' \
    <<<"$capacity" >/dev/null || fail "io.captf.capacity is not a {cpu, memory} object of strings: '$capacity'"
  jq -e '.operatingSystem == "linux" and (.architecture | IN("amd64", "arm64"))' \
    <<<"$node_info" >/dev/null || fail "io.captf.node-info is invalid: '$node_info'"
  if [[ -n ${MACHINE_ARCH:-} ]]; then
    [[ $(jq -r .architecture <<<"$node_info") == "$MACHINE_ARCH" ]] \
      || fail "io.captf.node-info architecture is not $MACHINE_ARCH: '$node_info'"
  fi
else
  what="a $role image"
  [[ $role != machine ]] || what="a machine image with MACHINE_LABELS=absent"
  [[ -z $(label io.captf.capacity) ]] || fail "io.captf.capacity set on $what"
  [[ -z $(label io.captf.node-info) ]] || fail "io.captf.node-info set on $what"
fi

# The variables schema is built from the module with tfcapi-lint, so it is
# there whenever the test has tfcapi-lint; tfcapi-lint image checks it parses.
if [[ -n ${TFCAPI_LINT:-} ]]; then
  jq -e 'type == "object" and .type == "object" and .additionalProperties == false' \
    <<<"$(label io.captf.variables-schema)" >/dev/null \
    || fail "io.captf.variables-schema is missing or is not a closed object schema: '$(label io.captf.variables-schema)'"
fi

root_mount=()
if [[ -n ${SMOKE_ROOT:-} ]]; then
  [[ -f $SMOKE_ROOT/main.tf.json ]] || { echo "smoke.sh: $SMOKE_ROOT/main.tf.json not found" >&2; exit 2; }
  root_mount=(-v "$(cd "$SMOKE_ROOT" && pwd):/captf/config:ro,Z" -e CAPTF_SMOKE_APPLY=1)
  echo "--- $image: runner-style apply and destroy of $SMOKE_ROOT (read-only, no network)"
else
  echo "--- $image: runner-style init and validate (read-only, no network)"
fi
# shellcheck disable=SC2016 # the script runs in the container's shell, which expands it
"$engine" run --rm --network=none --read-only "${root_mount[@]}" \
  --tmpfs /captf/work:rw,exec,mode=1777 --tmpfs /tmp:rw,exec,mode=1777 \
  -e HOME=/captf/work -e TF_DATA_DIR=/captf/work/.terraform \
  -e TF_CLI_CONFIG_FILE=/captf/work/cli.tfrc -e TF_IN_AUTOMATION=1 -e TF_INPUT=0 \
  --entrypoint /bin/sh "$image" -euc '
    for p in /captf/bin /var/run/captf/credentials; do
      [ ! -e "$p" ] || { echo "FAIL: reserved path $p exists" >&2; exit 1; }
    done
    [ -x /captf/runtime ] || { echo "FAIL: /captf/runtime not executable" >&2; exit 1; }
    [ -d /captf/providers ] || { echo "FAIL: /captf/providers missing" >&2; exit 1; }
    ls /captf/module/*.tf >/dev/null
    for p in tests test README.md DESIGN.md CONVENTIONS.md Makefile hack examples .github .terraform .terraform.lock.hcl; do
      [ ! -e "/captf/module/$p" ] || { echo "FAIL: /captf/module/$p is in the image" >&2; exit 1; }
    done
    cat > /captf/work/cli.tfrc <<EOF
provider_installation {
  filesystem_mirror {
    path    = "/captf/providers"
    include = ["*/*/*"]
  }
  direct {
    exclude = ["*/*/*"]
  }
}
EOF
    r=/captf/runtime
    $r version
    if [ -n "${CAPTF_SMOKE_APPLY:-}" ]; then
      mkdir /captf/work/root && cp /captf/config/main.tf.json /captf/work/root/
      cd /captf/work/root
      $r init -input=false -no-color
      $r validate -no-color
      $r apply -auto-approve -input=false -no-color
      $r output -json -no-color
      $r destroy -auto-approve -input=false -no-color
    else
      cp -R /captf/module /captf/work/root
      cd /captf/work/root
      $r init -backend=false -input=false -no-color
      $r validate -no-color
    fi
  '

if [[ -n ${TFCAPI_LINT:-} ]]; then
  echo "--- $image: tfcapi-lint image"
  archive=$(mktemp -d)
  trap 'rm -rf -- "$archive"' EXIT
  # tfcapi-lint reads an OCI image layout directory. podman writes one
  # directly; docker has no --format, but since Docker 25 its save archive is
  # an OCI image layout, so unpack it.
  case $engine in
    podman) podman save --format oci-dir -o "$archive/img" "$image" ;;
    *)
      mkdir "$archive/img"
      "$engine" save "$image" | tar -x -C "$archive/img"
      ;;
  esac
  if [[ ! -f $archive/img/oci-layout ]]; then
    echo "FAIL: $engine save did not produce an OCI image layout (Docker 25 or later is needed)" >&2
    exit 1
  fi
  # Lint the platform this host built: without --platform, tfcapi-lint picks
  # linux/amd64 from an index, and both engines' layouts are indexes.
  platform=$("$engine" image inspect --format '{{.Os}}/{{.Architecture}}' "$image")
  # shellcheck disable=SC2086 # a list of --allow-warning <id> flags
  "$TFCAPI_LINT" image --role "$role" --strict --platform "$platform" ${TFCAPI_LINT_ALLOW:-} "oci:$archive/img"
fi

echo "PASS: $image"
