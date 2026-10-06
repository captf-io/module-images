<h1 align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="72" height="72" alt="CAPTF"></a>
  <br>
  module-images
</h1>

<p align="center">Module images for every CAPTF reference module</p>

<p align="center">
  <a href="https://github.com/captf-io/module-images/actions/workflows/build.yml"><img
    src="https://img.shields.io/github/actions/workflow/status/captf-io/module-images/build.yml?branch=main&amp;label=build&amp;labelColor=161B3A&amp;style=flat-square"
    alt="build"></a>
  <a href="https://captf.io/docs/module-author/contract/index.html"><img
    src="https://img.shields.io/static/v1?label=contract&amp;message=v1alpha1&amp;color=A974FF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="contract v1alpha1"></a>
  <a href="https://captf.io/docs/"><img
    src="https://img.shields.io/static/v1?label=docs&amp;message=captf.io&amp;color=5B8CFF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="docs captf.io"></a>
  <a href="https://github.com/captf-io/module-images/blob/main/LICENSE.md"><img
    src="https://img.shields.io/static/v1?label=license&amp;message=Apache-2.0&amp;color=FFD84D&amp;labelColor=161B3A&amp;style=flat-square"
    alt="license Apache-2.0"></a>
</p>

> [!NOTE]
> **Pre-release.** CAPTF is `v1alpha1`: its API and its
> [module contract](https://captf.io/docs/module-author/contract/index.html)
> may still change between releases.

This repository builds the module images that the
[CAPTF provider](https://github.com/captf-io/cluster-api-provider-terraform)
runs as Kubernetes Jobs: one image per reference module, on Terraform and
on OpenTofu. It holds no module code. Each image packages a release of one
`terraform-<provider>-<role>` repository, the same release the
[Terraform Registry](https://registry.terraform.io/namespaces/captf-io)
serves, together with a mirror of the module's providers.

## Images

| Image | Module | Registry |
| --- | --- | --- |
| `ghcr.io/captf-io/module-images/aws-cluster` | [`terraform-aws-cluster`](https://github.com/captf-io/terraform-aws-cluster) | `captf-io/cluster/aws` |
| `ghcr.io/captf-io/module-images/aws-machine` | [`terraform-aws-machine`](https://github.com/captf-io/terraform-aws-machine) | `captf-io/machine/aws` |
| `ghcr.io/captf-io/module-images/aws-machinepool` | [`terraform-aws-machinepool`](https://github.com/captf-io/terraform-aws-machinepool) | `captf-io/machinepool/aws` |
| `ghcr.io/captf-io/module-images/azure-cluster` | [`terraform-azure-cluster`](https://github.com/captf-io/terraform-azure-cluster) | `captf-io/cluster/azure` |
| `ghcr.io/captf-io/module-images/azure-machine` | [`terraform-azure-machine`](https://github.com/captf-io/terraform-azure-machine) | `captf-io/machine/azure` |
| `ghcr.io/captf-io/module-images/azure-machinepool` | [`terraform-azure-machinepool`](https://github.com/captf-io/terraform-azure-machinepool) | `captf-io/machinepool/azure` |
| `ghcr.io/captf-io/module-images/gcp-cluster` | [`terraform-google-cluster`](https://github.com/captf-io/terraform-google-cluster) | `captf-io/cluster/google` |
| `ghcr.io/captf-io/module-images/gcp-machine` | [`terraform-google-machine`](https://github.com/captf-io/terraform-google-machine) | `captf-io/machine/google` |
| `ghcr.io/captf-io/module-images/gcp-machinepool` | [`terraform-google-machinepool`](https://github.com/captf-io/terraform-google-machinepool) | `captf-io/machinepool/google` |
| `ghcr.io/captf-io/module-images/noop-cluster` | [`terraform-noop-cluster`](https://github.com/captf-io/terraform-noop-cluster) | `captf-io/cluster/noop` |
| `ghcr.io/captf-io/module-images/noop-machine` | [`terraform-noop-machine`](https://github.com/captf-io/terraform-noop-machine) | `captf-io/machine/noop` |
| `ghcr.io/captf-io/module-images/noop-machinepool` | [`terraform-noop-machinepool`](https://github.com/captf-io/terraform-noop-machinepool) | `captf-io/machinepool/noop` |
| `ghcr.io/captf-io/module-images/oci-cluster` | [`terraform-oci-cluster`](https://github.com/captf-io/terraform-oci-cluster) | `captf-io/cluster/oci` |
| `ghcr.io/captf-io/module-images/oci-machine` | [`terraform-oci-machine`](https://github.com/captf-io/terraform-oci-machine) | `captf-io/machine/oci` |
| `ghcr.io/captf-io/module-images/oci-machinepool` | [`terraform-oci-machinepool`](https://github.com/captf-io/terraform-oci-machinepool) | `captf-io/machinepool/oci` |
| `ghcr.io/captf-io/module-images/openstack-cluster` | [`terraform-openstack-cluster`](https://github.com/captf-io/terraform-openstack-cluster) | `captf-io/cluster/openstack` |
| `ghcr.io/captf-io/module-images/openstack-machine` | [`terraform-openstack-machine`](https://github.com/captf-io/terraform-openstack-machine) | `captf-io/machine/openstack` |

The images are named under `module-images/` because this repository's
workflow creates them: each package is linked to this repository and
writable by its workflow, so adding an image needs no package settings.

OpenStack has no machine pool. Each image is multi-arch (`linux/amd64`,
`linux/arm64`) and built on both runtimes, from
[`terraform-base`](https://github.com/captf-io/terraform-base) and
[`opentofu-base`](https://github.com/captf-io/opentofu-base). The providers
are mirrored into the image, so a run needs no registry access. How to use
an image, and what its module needs and returns, is in its module's README
and in the [cloud modules](https://captf.io/docs/cloud-modules/) docs.

## Tags

An image's version is its module's release.

| Tag | Meaning |
| --- | --- |
| `vX.Y.Z-terraform`, `vX.Y.Z-opentofu` | Module release `vX.Y.Z` |
| `terraform`, `opentofu` | The newest module release |

Both tags are rebuilt whenever the image changes without a new module
release, such as a base image update, so they move to a new digest. Pin a
digest in anything you keep:
`ghcr.io/captf-io/module-images/aws-machine:v0.1.0-opentofu@sha256:…`.

The image's labels record where it came from: `org.opencontainers.image.version`
is the module release, `org.opencontainers.image.url` the module repository,
and `org.opencontainers.image.source` and `.revision` this repository and
the commit that built it. Machine images with a default instance shape also
carry `io.captf.capacity` and `io.captf.node-info` (image contract
"OCI labels").

## Signatures

`hack/fetch.sh` only builds
a module release whose `vX.Y.Z` tag is an annotated tag with a valid SSH
signature from a key in [`hack/allowed_signers`](hack/allowed_signers), and
whose tag points at the commit it fetches. A missing or bad signature fails
the build. `LOCAL_MODULES` builds skip the check (there is no tag) and say
so. To rotate the signing key, see the comment in `hack/allowed_signers`.

## How a release reaches an image

1. A module repository tags `vX.Y.Z`; the Terraform Registry publishes it.
2. Dependabot (daily) bumps that image's `version` in
   [`sources/versions.tf`](sources/versions.tf) in a pull request.
3. [CI](.github/workflows/build.yml) fetches the release (verifying its
   tag signature), builds the image
   on both runtimes, smoke-tests it and lints it with `tfcapi-lint`.
4. Merged to `main`, CI publishes `<image>:vX.Y.Z-<runtime>` and moves
   `<image>:<runtime>` to it.

A release that changes the module's providers also needs new lock files:
run `make lock IMAGES=<image>` and commit the result to the Dependabot
branch. A base image bump (Dependabot, weekly) republishes every image
under its current tags.

## Layout

| Path | What |
| --- | --- |
| [`images.json`](images.json) | The images: role, and per image the machine capacity labels, allowed `tfcapi-lint` warnings and the noop smoke-test root |
| [`sources/versions.tf`](sources/versions.tf) | The module release each image is built from, as Registry module blocks |
| `locks/<runtime>/<image>.terraform.lock.hcl` | Provider lock files: the providers the image mirrors |
| `Dockerfile.terraform`, `Dockerfile.opentofu` | One build for every image: `mirror → module → <role>` |
| [`test/smoke.sh`](test/smoke.sh) | Image smoke test: contract labels, then a runner-style run, read-only and offline |
| `test/roots/` | Root modules the smoke test applies to the noop images |
| `hack/` | `images.sh` (reads the two files above), `fetch.sh`, `lock.sh`, `build.sh` |

## Developing

The host needs make, git, podman (or docker with `ENGINE=docker`), jq and
Go. Every other tool runs in a container pinned by digest. `make help`
lists the targets.

```sh
make verify                       # images.json, versions and locks agree; headers, shellcheck, trivy
make test                         # fetch, build and smoke-test every image on both runtimes
make test CLOUDS=aws RUNTIMES=opentofu
make test IMAGES=noop-machine
make lock IMAGES=aws-machine      # after a module release that changes providers
```

The smoke test lints each image with `tfcapi-lint`, which it builds from a
provider checkout at `../cluster-api-provider-terraform`; set
`PROVIDER_DIR` to use another one, or `TFCAPI_LINT` to a ready binary.

To try an unreleased module change in an image, build from local
checkouts of the module repositories:

```sh
make test IMAGES=aws-machine LOCAL_MODULES=..   # uses ../terraform-aws-machine
```

The module code itself (formatting, validation, unit tests, `tflint`,
`tfcapi-lint module`, `trivy`) is checked in its own repository.

### Adding an image

1. Add the module to [`images.json`](images.json) and a matching block to
   [`sources/versions.tf`](sources/versions.tf).
2. Run `make lock IMAGES=<image>`, then `make verify test IMAGES=<image>`.

<br>
<p align="center">
  <img
    src="https://captf.io/assets/readme/divider.svg"
    width="100%" height="4" alt="">
</p>
<p align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="40" height="40" alt="CAPTF"></a>
  <br>
  <a href="https://captf.io/docs/"
    ><b>Documentation</b></a> ·
  <a href="https://captf.io/docs/getting-started/quick-start.html"
    ><b>Quick start</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/CONTRIBUTING.md"
    ><b>Contributing</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/SECURITY.md"
    ><b>Security</b></a>
  <br>
  <sub>Built for
    <a href="https://cluster-api.sigs.k8s.io/">Cluster API</a>.
    <a href="https://github.com/captf-io/module-images/blob/main/LICENSE.md"
    >Apache 2.0</a>.</sub>
</p>
