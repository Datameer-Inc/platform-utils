#!/usr/bin/env bash

set -euo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
source "${script_dir}/../../functions.sh"
config_file="${PU_LOCAL_ROOT}/datadog/.env"

determine_dd_api_key() {
  export DD_API_KEY DD_AGENT_ENABLED
  if [ -z "${DD_API_KEY:-}" ]; then
    # aws default retrieval
    if command -v aws > /dev/null 2>&1; then
      AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
      # try in default region
      [[ "${AWS_DEFAULT_REGION}" == 'us-east-1' ]] || DD_API_KEY=$(aws ssm --region=$AWS_DEFAULT_REGION get-parameter --with-decryption --output text --name '/spotlight/shared-resources/datadog_api_key' --query 'Parameter.Value' 2> /dev/null || true)
      # try in us-east-1 if empty
      [ -n "${DD_API_KEY:-}" ] || DD_API_KEY==$(aws ssm --region=us-east-1 get-parameter --with-decryption --output text --name '/spotlight/shared-resources/datadog_api_key' --query 'Parameter.Value' 2> /dev/null || true)
    fi
  fi
}

if [ -f "${config_file}" ]; then
  info "Found datadog config '${config_file}'..."
  install_ansible
  set -a
  source "${config_file}"
  set +a
  # disable if no api key
  determine_dd_api_key
  [[ -z "${DD_API_KEY:-}" ]] && DD_AGENT_ENABLED="false" || DD_AGENT_ENABLED="true"
  # auto detect component if not set
  [ -n "${PLAYBOOK_COMPONENT:-}" ] || component_detection
  # provision
  default_playbook="${PU_TOOLS_ROOT}/datadog/components/${PLAYBOOK_COMPONENT}/playbook.yaml"
  local_playbook="${PU_LOCAL_ROOT}/datadog/components/${PLAYBOOK_COMPONENT}/playbook.yaml"
  playbook="${default_playbook}"
  [ -f "${local_playbook}" ] && playbook="${local_playbook}" || playbook="${default_playbook}"
  if [ -f "${playbook}" ]; then
    if ansible-galaxy role list 2> /dev/null | grep -q datadog.datadog; then
      info "Ansible role datadog.datadog already installed. Doing nothing..."
    else
      ansible-galaxy install datadog.datadog
    fi
    ansible-playbook "${playbook}"
  else
    info "Playbook '${playbook}' NOT found. Ignoring..."
  fi
else
  info "Could not find datadog config '${config_file}'. Ignoring..."
fi
