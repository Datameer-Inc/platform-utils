#!/usr/bin/env bash

set -euo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
source "${script_dir}/scripts/functions.sh"

export PU_TOOLS_ROOT="${script_dir}/tools"

info "Processing tools..."
for tool_dir in $(find "${PU_TOOLS_ROOT}" -maxdepth 1 -type d); do
  tool_name=$(basename "${tool_dir}")
  if [ -x "${PU_TOOLS_ROOT}/${tool_name}/process.sh" ]; then
    info "Found ${tool_name}"
    "${PU_TOOLS_ROOT}/${tool_name}/process.sh"
  fi
done
