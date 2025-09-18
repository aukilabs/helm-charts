#!/usr/bin/env bash

# Use dummy image for now to make tests pass

yq -i '(.server.image.repository = "registry.k8s.io/pause") | (.server.image.tag = "3.10")' "$(dirname "$0")/../values.yaml"
yq -i '(.ui.image.repository = "registry.k8s.io/pause") | (.ui.image.tag = "3.10")' "$(dirname "$0")/../values.yaml"
yq -i '(.worker.image.repository = "registry.k8s.io/pause") | (.worker.image.tag = "3.10")' "$(dirname "$0")/../values.yaml"
yq -i '(.server.enableProbes = false) | (.ui.enableProbes = false) | (.worker.enableProbes = false)' "$(dirname "$0")/../values.yaml"
