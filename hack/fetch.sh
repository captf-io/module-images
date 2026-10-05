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

# Put each image's module into build/src/<image>/, the directory the
# Dockerfiles copy to /captf/module. The module is the release pinned in
# sources/versions.tf: tag v<version> of
# github.com/captf-io/terraform-<provider>-<role>. Only the module itself is
# kept: the top-level *.tf and *.tf.json files and templates/. The tests,
# README, tooling and examples of the module repository never reach an image.
#
# build/src/<image>.ref records what is there ("<repo> <tag> <commit>"), so
# a second run only checks the tag with `git ls-remote` and skips the clone.
#
# Usage: hack/fetch.sh <image>...
# Env:   LOCAL_MODULES (a directory holding terraform-<provider>-<role>
#        checkouts, e.g. `..`: copy each module from its working tree,
#        uncommitted changes included, to test a module change in an image
#        before it is released; the .ref then says `local`)
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

[[ $# -gt 0 ]] || { echo "usage: fetch.sh <image>..." >&2; exit 2; }

# export_module <source-dir> <dest-dir>: copy the module files only.
export_module() {
  local src=$1 dest=$2
  local -a paths=()
  while IFS= read -r -d '' f; do paths+=("${f#"$src"/}"); done \
    < <(find "$src" -maxdepth 1 -type f \( -name '*.tf' -o -name '*.tf.json' \) -print0 | sort -z)
  [[ ${#paths[@]} -gt 0 ]] || { echo "fetch.sh: no *.tf files in $src" >&2; return 1; }
  [[ ! -d $src/templates ]] || paths+=(templates)
  mkdir -p "$dest"
  tar -C "$src" -cf - "${paths[@]}" | tar -C "$dest" -xf -
}

for image in "$@"; do
  env=$(hack/images.sh env "$image")
  repo=$(sed -n 's/^repo=//p' <<<"$env")
  tag=$(sed -n 's/^tag=//p' <<<"$env")
  dest=build/src/$image
  ref=build/src/$image.ref
  url=https://github.com/$repo.git

  if [[ -n ${LOCAL_MODULES:-} ]]; then
    src="$LOCAL_MODULES/${repo#*/}"
    [[ -f $src/versions.tf ]] || { echo "fetch.sh: $src/versions.tf not found" >&2; exit 1; }
    stamp="$repo local $(cd "$src" && pwd)"
  else
    # A tag ref and, for an annotated tag, the commit it points to (^{}).
    commit=$(git ls-remote --tags "$url" "refs/tags/$tag" "refs/tags/$tag^{}" \
      | awk '{ c[$2] = $1 } END { t = "refs/tags/'"$tag"'"; print (t "^{}" in c) ? c[t "^{}"] : c[t] }')
    [[ $commit =~ ^[0-9a-f]{40}$ ]] || { echo "fetch.sh: $repo has no tag $tag" >&2; exit 1; }
    stamp="$repo $tag $commit"
    if [[ -f $ref && $(<"$ref") == "$stamp" && -d $dest ]]; then
      echo "fetch: $image: $repo $tag ($commit), up to date"
      continue
    fi
  fi

  tmp=$(mktemp -d)
  trap 'rm -rf -- "$tmp"' EXIT
  if [[ -n ${LOCAL_MODULES:-} ]]; then
    export_module "$src" "$tmp/module"
  else
    # Fetch the commit the tag resolved to, not the tag: what is built is
    # exactly what the .ref names, even if the tag moves in between.
    git init --quiet "$tmp/repo"
    git -C "$tmp/repo" fetch --quiet --depth 1 "$url" "$commit"
    git -C "$tmp/repo" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
    got=$(git -C "$tmp/repo" rev-parse HEAD)
    [[ $got == "$commit" ]] || { echo "fetch.sh: fetched $got from $repo, want $commit ($tag)" >&2; exit 1; }
    export_module "$tmp/repo" "$tmp/module"
  fi

  # Replace build/src/<image> only: refuse anything that is not a plain
  # directory at the expected path.
  case $dest in build/src/[a-z0-9]*-*) ;; *) echo "fetch.sh: refusing to write '$dest'" >&2; exit 1 ;; esac
  if [[ -e $dest ]]; then
    [[ -d $dest && ! -L $dest ]] || { echo "fetch.sh: $dest is not a directory" >&2; exit 1; }
    rm -rf -- "$dest"
  fi
  mkdir -p build/src
  mv "$tmp/module" "$dest"
  printf '%s\n' "$stamp" >"$ref"
  rm -rf -- "$tmp"
  trap - EXIT
  echo "fetch: $image: $stamp"
done
