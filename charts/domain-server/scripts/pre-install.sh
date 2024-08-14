#!/usr/bin/env bash

pip3 install web3
private_key="$(python3 -c "from web3 import Web3; w3 = Web3(); acc = w3.eth.account.create(); print(f'{w3.to_hex(acc.key)}')")"
yq -i ".secrets.wallet_private_key = \"${private_key}\"" "$(dirname "$0")/../values.yaml"
