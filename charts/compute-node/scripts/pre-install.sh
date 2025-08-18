#!/usr/bin/env bash

# Set to dummy image to make tests pass

yq -i '(.server.image.repository = "registry.k8s.io/pause") | (.server.image.tag = "3.10")' "$(dirname "$0")/../values.yaml"
yq -i '(.ui.image.repository = "registry.k8s.io/pause") | (.ui.image.tag = "3.10")' "$(dirname "$0")/../values.yaml"
