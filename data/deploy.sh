#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"

cd terraform
terraform apply -auto-approve

popd
