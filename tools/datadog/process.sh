#!/usr/bin/env bash

set -euo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
source "${script_dir}/../../functions.sh"

config_file="${PU_LOCAL_ROOT}/datadog/.env"
if [ -f "${config_file}" ]; then
  info "Found datadog config '${config_file}'..."
  install_ansible
  set -a
  . "${config_file}"
  set +a
  # disable if no api key
  [ -n "${DD_API_KEY:-}" ] || export DD_AGENT_ENABLED=false
  # auto detect component if not set
  [ -n "${PLAYBOOK_COMPONENT:-}" ] || component_detection
  # provision
  playbook="${PU_TOOLS_ROOT}/datadog/components/${PLAYBOOK_COMPONENT}/dd_playbook.yaml"
  if [ -f "${playbook}" ]; then
    ansible-galaxy install datadog.datadog
    ansible-playbook "${playbook}"
  else
    info "Playbook '${playbook}' NOT found. Ignoring..."
  fi
else
  info "Could not find datadog config '${config_file}'. Ignoring..."
fi
