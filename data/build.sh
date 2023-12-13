#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"

sam build
sam validate --lint

cd .aws-sam/build/ProductivityDataImport
rm -f ../../ProductivityDataImport.zip
zip -r ../../ProductivityDataImport.zip .

popd
