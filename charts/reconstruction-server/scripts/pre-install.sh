#!/usr/bin/env bash

# Set to dummy image to make tests pass as the real image isn't public yet

yq -i '(.image.repository = "busybox") | (.image.tag = "latest")' "$(dirname "$0")/../values.yaml"
