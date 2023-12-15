#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"

rm -fr .aws-sam

sam build
sam validate --lint

cd "$script_dir/.aws-sam/build/ProductivityDataImport"
zip -r ../../ProductivityDataImport.zip .

cd "$script_dir/.aws-sam/build/SQSListener"
zip -r ../../SQSListener.zip .

cd "$script_dir/reports/docker"
docker build --no-cache -t ct20231211-reports .

popd
