#!/usr/bin/env bash

set -euo pipefail

currentScriptDir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
scriptsDir="${currentScriptDir}/scripts"
source "${scriptsDir}/functions.sh"

checkVars() {
  if [ -z "${INSTALL_USER:-}" ]; then
    prompt INSTALL_USER "Which user will use the installation (e.g. ec2-user)? Leave blank to use the current user." "ec2-user"
  else
    info "Found INSTALL_USER = '$INSTALL_USER'"
  fi
  if [ -z "${INSTALL_USER_HOME:-}" ]; then
    prompt INSTALL_USER_HOME "Where is your Linux Home Directory? Leave blank to use the current user's Home." "$(getent passwd "$INSTALL_USER" | cut -d: -f6)"
  else
    info "Found INSTALL_USER_HOME = '$INSTALL_USER_HOME'"
  fi
  if [ -z "${PLATFORM_ECR_IMAGE:-}" ]; then
    prompt PLATFORM_ECR_IMAGE "What is the Platform ECR Image URI?" ""
  else
    info "Found PLATFORM_ECR_IMAGE = '$PLATFORM_ECR_IMAGE'"
  fi
  if [ -z "${AWS_ECR_CREDENTIALS:-}" ]; then
    prompt AWS_ECR_CREDENTIALS "What are your AWS ECR Credentials? Input in the form: <AWS_ACCESS_KEY_ID>:<AWS_SECRET_ACCESS_KEY>" ""
  else
    info "Found AWS_ECR_CREDENTIALS!"
  fi
}

activateNetIpForward() {
    if [ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]; then
        info "DEVOP-781: OK -> $(sysctl net.ipv4.ip_forward)"
    else
        if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
            info "DEVOP-781: REPLACING net.ipv4.ip_forward"
            sed -i.bak "s/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf
            rm -f /etc/sysctl.conf.bak
        else
            info "DEVOP-781: APPENDING net.ipv4.ip_forward"
            echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
        fi
        info "DEVOP-781: restarting network"
        systemctl restart network
        if [ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]; then
            info "DEVOP-781: OK -> $(sysctl net.ipv4.ip_forward)"
        else
            info "Still broken after network restart -> $(sysctl net.ipv4.ip_forward)"
            exit 1
        fi
    fi
}

dnsAutoConfigure() {
    if [ ! -f /etc/init.d/dns-auto-configure ]; then
        info "dns-auto-configure - Cannot find dns-auto-configure service. Installing now..."
        bash -c "${currentScriptDir}/scripts/dns-auto-configure-scripts/dns-auto-configure-setup"
    else
        info "dns-auto-configure - found service, no need to install."
    fi
}

provisioningSteps() {
    local check_only=${1:-}
    if ! command -v aws > /dev/null; then
      if [ -z "${check_only}" ]; then
        info "Installing AWS CLI..."
        curl --fail -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
        unzip -u -q awscliv2.zip
        ./aws/install --bin-dir /usr/bin --update
      else
        die "Provisioning not performed. Please run script as sudo first."
      fi
    fi
    aws --version

    if ! command -v jq > /dev/null; then
      if [ -z "${check_only}" ]; then
        info "Installing jq..."
        yum install -q -y jq
      else
        die "Provisioning not performed. Please run script as sudo first."
      fi
    fi
    jq --version

    if ! command -v docker > /dev/null; then
      if [ -z "${check_only}" ]; then
        info "Installing Docker..."
        amazon-linux-extras install -q -y docker
        systemctl enable docker
        systemctl start docker
      else
        die "Provisioning not performed. Please run script as sudo first."
      fi
    fi
    docker --version

    if ! command -v psql > /dev/null; then
      if [ -z "${check_only}" ]; then
        info "Installing Postgres..."
        amazon-linux-extras install -q -y postgresql11
      else
        die "Provisioning not performed. Please run script as sudo first."
      fi
    fi
    psql --version

    if ! command -v docker-compose > /dev/null; then
      if [ -z "${check_only}" ]; then
        info "Installing docker-compose..."
        curl --fail -sSL "https://github.com/docker/compose/releases/download/1.28.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
      else
        die "Provisioning not performed. Please run script as sudo first."
      fi
    fi
    docker-compose --version
}

dockerPullPlatform() {
  local awsKey=$(echo ${AWS_ECR_CREDENTIALS//:*})
  local awsSec=$(echo ${AWS_ECR_CREDENTIALS//*:})
  local platformEcrImageRegistry=$(echo $PLATFORM_ECR_IMAGE | cut -d/ -f 1)
  local platformEcrImageRegion=$(echo $PLATFORM_ECR_IMAGE | cut -d. -f 4)
  info "Attempting to login to the ECR repo '${platformEcrImageRegistry}'..."
  AWS_ACCESS_KEY_ID=$awsKey AWS_SECRET_ACCESS_KEY=$awsSec \
      aws ecr get-login-password --region "${platformEcrImageRegion}" | \
      docker login --username AWS --password-stdin "${platformEcrImageRegistry}"
  docker pull ${PLATFORM_ECR_IMAGE}
}

setupPlatformScripts() {
    docker create --name tmp-platform-init ${PLATFORM_ECR_IMAGE} bash
    if ! rm -rf $INSTALL_USER_HOME/docker-compose; then
      die "Could not delete the existing '$INSTALL_USER_HOME/docker-compose'. Please run the setup.sh as root to provision the instance and start scripts."
    fi
    docker cp tmp-platform-init:/docker-compose $INSTALL_USER_HOME/docker-compose
    docker rm tmp-platform-init
    chown -R $INSTALL_USER $INSTALL_USER_HOME/docker-compose
    cd $INSTALL_USER_HOME/docker-compose || exit 1
    make
}

# Main

info "Hello from $(whoami) in $(pwd)"
checkVars

# Run as root to setup instance
if [[ $EUID -eq 0 ]]; then
    info "Setting up Instance as root user..."
    info "Preemptively adding docker group and giving $INSTALL_USER membership..."
    [ $(getent group docker) ] || groupadd -r docker
    usermod -aG docker $INSTALL_USER
    activateNetIpForward
    dnsAutoConfigure
    provisioningSteps
else
  provisioningSteps 'true'
  info "Pulling Platform without setting up instance..."
fi

info "Setting up Platform..."
dockerPullPlatform
setupPlatformScripts
info "Instance now provisioned. Checking docker group membership..."
if id "${INSTALL_USER}" | grep -q "(docker)"; then
  info "User '${INSTALL_USER}' has the docker group."
else
  info "WARNING: User '${INSTALL_USER}' does not have the docker group."
  info "WARNING: Please logout and login as ${INSTALL_USER} before continuing with the steps below."
fi
echo
info "ATTENTION: Login again if required (see above)"
info "To start spotlight, please copy and paste the following:"
echo "{
  export AWS_ECR_CREDENTIALS=${AWS_ECR_CREDENTIALS}
  cd ${INSTALL_USER_HOME}/docker-compose
  make start/spotlight/aws-dev
}"
