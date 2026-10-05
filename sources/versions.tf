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

# The module release each image is built from: one block per image in
# images.json, named after the image. Nothing initializes or applies this
# configuration. hack/images.sh reads it, hack/fetch.sh clones the release's
# tag (v<version>) from github.com/captf-io/terraform-<provider>-<role>, and
# Dependabot (terraform ecosystem) bumps `version` when a module repository
# publishes a release to the Terraform Registry. The image tag is the module
# tag: version 0.1.0 publishes <image>:v0.1.0-<runtime>.
#
# Keep one attribute per line and an exact version: hack/images.sh parses
# this file line by line, and `make check-images` rejects anything else.

module "aws-cluster" {
  source  = "captf-io/cluster/aws"
  version = "0.1.0"
}

module "aws-machine" {
  source  = "captf-io/machine/aws"
  version = "0.1.0"
}

module "aws-machinepool" {
  source  = "captf-io/machinepool/aws"
  version = "0.1.0"
}

module "azure-cluster" {
  source  = "captf-io/cluster/azure"
  version = "0.1.0"
}

module "azure-machine" {
  source  = "captf-io/machine/azure"
  version = "0.1.0"
}

module "azure-machinepool" {
  source  = "captf-io/machinepool/azure"
  version = "0.1.0"
}

module "gcp-cluster" {
  source  = "captf-io/cluster/google"
  version = "0.1.0"
}

module "gcp-machine" {
  source  = "captf-io/machine/google"
  version = "0.1.0"
}

module "gcp-machinepool" {
  source  = "captf-io/machinepool/google"
  version = "0.1.0"
}

module "noop-cluster" {
  source  = "captf-io/cluster/noop"
  version = "0.1.0"
}

module "noop-machine" {
  source  = "captf-io/machine/noop"
  version = "0.1.0"
}

module "noop-machinepool" {
  source  = "captf-io/machinepool/noop"
  version = "0.1.0"
}

module "oci-cluster" {
  source  = "captf-io/cluster/oci"
  version = "0.1.0"
}

module "oci-machine" {
  source  = "captf-io/machine/oci"
  version = "0.1.0"
}

module "oci-machinepool" {
  source  = "captf-io/machinepool/oci"
  version = "0.1.0"
}

module "openstack-cluster" {
  source  = "captf-io/cluster/openstack"
  version = "0.1.0"
}

module "openstack-machine" {
  source  = "captf-io/machine/openstack"
  version = "0.1.0"
}
