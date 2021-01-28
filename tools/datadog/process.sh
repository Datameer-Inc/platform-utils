#!/usr/bin/env bash

set -euo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
source "${script_dir}/../../functions.sh"

install_ansible
echo "Processing datadog..."
if [ -e "${PU_TOOLS_ROOT}/datadog/ansible.properties" ]; then
    echo "Hi"
fi
