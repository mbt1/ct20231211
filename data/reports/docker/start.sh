#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
pushd "$script_dir"

docker build -t ct20231211-reports .
docker run -v ~/.aws:/root/.aws:ro ct20231211-reports


popd