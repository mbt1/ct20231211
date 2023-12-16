#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"
cd "../reports/docker"

# Variables
ECR_REPOSITORY_URL="$1"
IMAGE_TAG="latest"  

aws ecr get-login-password --region $(aws configure get region) | docker login --username AWS --password-stdin ${ECR_REPOSITORY_URL}

docker build -t ${ECR_REPOSITORY_URL}:${IMAGE_TAG} .

docker push ${ECR_REPOSITORY_URL}:${IMAGE_TAG}

popd