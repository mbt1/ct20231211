#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"

echo Build started on `date`
npm run build
echo Deploy started on `date`
aws s3 sync build/ s3://$TF_VAR_S3_WEBSITE_BUCKET 
echo Cloudfront Cache invalidation started on `date`
aws cloudfront create-invalidation --distribution-id $TF_VAR_CLOUDFRONT_ID --paths "/*"
echo Deploy finished on `date`

popd
