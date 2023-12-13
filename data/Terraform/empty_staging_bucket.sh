#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"

STAGING_BUCKET_NAME=$(terraform output -raw staging_bucket_name)
echo "Emptying the bucket: $STAGING_BUCKET_NAME"
aws s3 rm s3://$STAGING_BUCKET_NAME --recursive

popd