#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
(cd "$script_dir/reports"; jupyter notebook;)
