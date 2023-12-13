#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"

STAGING_BUCKET_NAME=$(terraform output -raw staging_bucket_name)
echo "Emptying the bucket: $STAGING_BUCKET_NAME"
aws s3 rm s3://$STAGING_BUCKET_NAME --recursive

if [ $? -eq 0 ]; then
    echo "Bucket emptied successfully."
    echo "Proceeding with Terraform destroy..."
    terraform destroy -auto-approve
    popd
else
    echo "Failed to empty the bucket. Aborting Terraform destroy."
    popd
    exit 1
fi
