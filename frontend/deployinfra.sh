#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"

cd terraform
terraform apply -auto-approve

#----------------------------------------------------------------------------------------------
#----|=|-<<- No spaces here!
output=$(terraform output -json | jq -r 'to_entries|map("TF_VAR_\(.key)=\(.value.value)")|.[]')
#----------------------------------------------------------------------------------------------

while IFS= read -r line; do
    export "$line"
done <<< "$output"

echo "Exported Terraform Outputs:"
env | grep -E '^(TF_VAR_.*)='

popd
