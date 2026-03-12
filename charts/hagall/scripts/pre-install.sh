#!/usr/bin/env bash

set -euo pipefail

private_key="0x$(openssl rand -hex 32)"
yq -i ".secrets.privateKey = \"${private_key}\"" "$(dirname "$0")/../values.yaml"
