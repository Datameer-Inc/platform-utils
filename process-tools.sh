#!/usr/bin/env bash

set -euo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
source "${script_dir}/functions.sh"

PU_TOOLS_ROOT="${script_dir}/tools"

process_tools() {
  local tool_name
  printf "Processing tools..."
  for tool_dir in $(find "${PU_TOOLS_ROOT}" -maxdepth 1 -type d); do
    tool_name=$(basename "${tool_dir}")
    if [ -x "${PU_TOOLS_ROOT}/${tool_name}/process.sh" ]; then
      "${PU_TOOLS_ROOT}/${tool_name}/process.sh"
    fi
  done
}
process_tools
