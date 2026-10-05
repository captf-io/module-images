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

# Reads the two files that define the images: images.json (role and build
# values per image) and sources/versions.tf (the module release per image).
# The Makefile and the build workflow call it; nothing else parses either
# file.
#
# Usage:
#   hack/images.sh list [cloud...]   image names, all or those of the clouds
#   hack/images.sh clouds            the clouds (image name prefixes) as
#                                    compact JSON, for the build matrix
#   hack/images.sh env <image>       KEY=value lines for one image:
#                                    role, module, version, tag, repo,
#                                    capacity, arch, allow, smoke_root
#   hack/images.sh matrix            the build matrix as compact JSON:
#                                    [{"image", "runtime"}] for every image
#                                    and both runtimes
#   hack/images.sh check             fail unless the two files agree with
#                                    each other and with locks/
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

manifest=images.json
sources=sources/versions.tf
runtimes=(terraform opentofu)

die() { echo "images.sh: $*" >&2; exit 1; }

# sources_tsv: one "name<TAB>source<TAB>version" line per module block.
sources_tsv() {
  awk '
    /^module "[^"]+" \{$/ { name = $2; gsub(/"/, "", name); src = ""; ver = ""; next }
    name != "" && /^  source *= *"[^"]*"$/ { src = $0; sub(/^[^"]*"/, "", src); sub(/"$/, "", src); next }
    name != "" && /^  version *= *"[^"]*"$/ { ver = $0; sub(/^[^"]*"/, "", ver); sub(/"$/, "", ver); next }
    name != "" && /^\}$/ { print name "\t" src "\t" ver; name = ""; next }
    name != "" { printf "images.sh: %s: unexpected line in module \"%s\": %s\n", FILENAME, name, $0 > "/dev/stderr"; exit 1 }
  ' "$sources"
}

source_of() { sources_tsv | awk -F'\t' -v n="$1" '$1 == n { print $2 "\t" $3 }'; }

images() { jq -r 'keys[]' "$manifest"; }

cmd=${1:-}
shift || true
case $cmd in
  list)
    if [[ $# -eq 0 ]]; then
      images
    else
      for cloud in "$@"; do images | grep -E "^${cloud}-" || die "no images for cloud '$cloud'"; done
    fi
    ;;

  clouds)
    images | cut -d- -f1 | sort -u | jq -R . | jq -sc .
    ;;

  env)
    image=${1:?usage: images.sh env <image>}
    jq -e --arg i "$image" 'has($i)' "$manifest" >/dev/null || die "unknown image '$image' (not in $manifest)"
    line=$(source_of "$image")
    [[ -n $line ]] || die "no module \"$image\" block in $sources"
    module=${line%%$'\t'*}
    version=${line#*$'\t'}
    IFS=/ read -r ns role_from_source provider <<<"$module"
    jq -r --arg i "$image" '.[$i] | [
        "role=\(.role)",
        "capacity=\(if .capacity then (.capacity | tojson) else "" end)",
        "arch=\(.arch // "")",
        "allow=\([(.allowWarnings // [])[] | "--allow-warning \(.)"] | join(" "))",
        "smoke_root=\(.smokeRoot // "")"
      ] | .[]' "$manifest"
    echo "module=$module"
    echo "version=$version"
    echo "tag=v$version"
    echo "repo=$ns/terraform-$provider-$role_from_source"
    ;;

  matrix)
    images | jq -R . | jq -sc '[.[] as $i | ("terraform", "opentofu") as $r | {image: $i, runtime: $r}]'
    ;;

  check)
    rc=0
    complain() { echo "check-images: $*" >&2; rc=1; }
    tsv=$(sources_tsv) || die "cannot parse $sources"
    jq -e 'type == "object" and length > 0' "$manifest" >/dev/null || die "$manifest is not a non-empty object"
    mapfile -t names < <(images)
    mapfile -t source_names < <(cut -f1 <<<"$tsv")
    for n in "${source_names[@]}"; do
      jq -e --arg i "$n" 'has($i)' "$manifest" >/dev/null || complain "$sources: module \"$n\" has no entry in $manifest"
    done
    for n in "${names[@]}"; do
      [[ $n =~ ^[a-z0-9]+-(cluster|machine|machinepool)$ ]] || complain "$n: an image is named <cloud>-<role>"
      line=$(awk -F'\t' -v n="$n" '$1 == n { print $2 "\t" $3 }' <<<"$tsv")
      if [[ -z $line ]]; then complain "$n: no module \"$n\" block in $sources"; continue; fi
      module=${line%%$'\t'*}
      version=${line#*$'\t'}
      role=$(jq -r --arg i "$n" '.[$i].role' "$manifest")
      [[ $role == "${n##*-}" ]] || complain "$n: role is '$role', but the name says '${n##*-}'"
      [[ $module =~ ^captf-io/${role}/[a-z0-9]+$ ]] \
        || complain "$n: source '$module' is not a captf-io/$role/<provider> registry address"
      [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || complain "$n: version '$version' is not an exact X.Y.Z"
      if [[ $role == machine ]]; then
        jq -e --arg i "$n" '.[$i] | (has("capacity") == has("arch"))
          and (if has("capacity") then (.capacity | type == "object" and (.cpu | type == "string") and (.memory | type == "string")) and (.arch | IN("amd64", "arm64")) else true end)' \
          "$manifest" >/dev/null \
          || complain "$n: set both capacity {cpu, memory} (strings) and arch (amd64|arm64), or neither"
      else
        jq -e --arg i "$n" '.[$i] | (has("capacity") or has("arch")) | not' "$manifest" >/dev/null \
          || complain "$n: capacity and arch are for machine images only"
      fi
      smoke_root=$(jq -r --arg i "$n" '.[$i].smokeRoot // ""' "$manifest")
      [[ -z $smoke_root || -f $smoke_root/main.tf.json ]] || complain "$n: $smoke_root/main.tf.json not found"
      for rt in "${runtimes[@]}"; do
        [[ -f locks/$rt/$n.terraform.lock.hcl ]] || complain "$n: locks/$rt/$n.terraform.lock.hcl not found; run 'make lock IMAGES=$n'"
      done
    done
    for rt in "${runtimes[@]}"; do
      for f in locks/"$rt"/*.terraform.lock.hcl; do
        [[ -e $f ]] || continue
        n=$(basename "$f" .terraform.lock.hcl)
        jq -e --arg i "$n" 'has($i)' "$manifest" >/dev/null || complain "$f: no image '$n' in $manifest"
      done
    done
    [[ $rc -eq 0 ]] || exit 1
    echo "check-images: ok (${#names[@]} images)"
    ;;

  *)
    sed -n '/^# Usage:/,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//' >&2
    exit 2
    ;;
esac
