#!/usr/bin/env bash

set -euo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
source "${script_dir}/../../scripts/functions.sh"
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

source_envs() {
  set -a
  source "${1}"
  set +a
}

run_playbook() {
  local playbook=$1
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
}

if [ -f "${config_file}" ]; then
  info "Found datadog config '${config_file}'..."

  install_ansible

  source_envs "${config_file}"

  # disable if no api key
  determine_dd_api_key
  if [[ -z "${DD_API_KEY:-}" ]]; then
    info "DD_API_KEY has not been found. Disabling agent."
    DD_AGENT_ENABLED="false"
  else
    info "DD_API_KEY has been found. Enabling agent."
    DD_AGENT_ENABLED="true"
  fi

  # auto detect component if not set
  [ -n "${PLAYBOOK_COMPONENT:-}" ] || component_detection

  # check local overrides
  tools_envs="${PU_TOOLS_ROOT}/datadog/components/${PLAYBOOK_COMPONENT}/${PLAYBOOK_NAME}.sh"
  local_envs="${PU_LOCAL_ROOT}/datadog/components/${PLAYBOOK_COMPONENT}/${PLAYBOOK_NAME}.sh"
  tools_book="${PU_TOOLS_ROOT}/datadog/components/${PLAYBOOK_COMPONENT}/${PLAYBOOK_NAME}.yaml"
  local_book="${PU_LOCAL_ROOT}/datadog/components/${PLAYBOOK_COMPONENT}/${PLAYBOOK_NAME}.yaml"
  # extra sauce?
  if [ -f "${local_envs}" ]; then
    source_envs "${local_envs}"
  elif [ -f "${tools_envs}" ]; then
    source_envs "${tools_envs}"
  fi
  # run playbook
  if [ -f "${local_book}" ]; then
    run_playbook "${local_book}"
  elif [ -f "${tools_book}" ]; then
    run_playbook "${tools_book}"
  fi
  # provision
else
  info "Could not find datadog config '${config_file}'. Ignoring..."
fi
