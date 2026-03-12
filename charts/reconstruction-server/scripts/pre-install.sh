#!/usr/bin/env bash

set -euo pipefail

# Set to a dummy image for chart tests so the install only validates the chart wiring.
yq -i '(.image.repository = "registry.k8s.io/pause") | (.image.tag = "3.10")' "$(dirname "$0")/../values.yaml"
