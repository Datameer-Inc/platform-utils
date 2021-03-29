#!/usr/bin/env bash

set -euo pipefail

currentScriptDir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
scriptsDir="${currentScriptDir}/scripts"
source "${scriptsDir}/functions.sh"

checkVars() {
  if [ -z "${INSTALL_USER:-}" ]; then
    prompt INSTALL_USER "Which user will use the installation (e.g. ec2-user)? Leave blank to use the current user." "$(whoami)"
  else
    echo "Found INSTALL_USER = '$INSTALL_USER'"
  fi
  if [ -z "${INSTALL_USER_HOME:-}" ]; then
    prompt INSTALL_USER_HOME "Where is your Linux Home Directory? Leave blank to use the current user's Home." "$(getent passwd "$INSTALL_USER" | cut -d: -f6)"
  else
    echo "Found INSTALL_USER_HOME = '$INSTALL_USER_HOME'"
  fi
  if [ -z "${PLATFORM_ECR_IMAGE:-}" ]; then
    prompt PLATFORM_ECR_IMAGE "What is the Platform ECR Image URI?" ""
  else
    echo "Found PLATFORM_ECR_IMAGE = '$PLATFORM_ECR_IMAGE'"
  fi
  if [ -z "${AWS_ECR_CREDENTIALS:-}" ]; then
    prompt AWS_ECR_CREDENTIALS "What are your AWS ECR Credentials? Input in the form: <AWS_ACCESS_KEY_ID>:<AWS_SECRET_ACCESS_KEY>" ""
  else
    echo "Found AWS_ECR_CREDENTIALS!"
  fi
}

activateNetIpForward() {
    if [ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]; then
        echo "DEVOP-781: OK -> $(sysctl net.ipv4.ip_forward)"
    else
        if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
            echo "DEVOP-781: REPLACING net.ipv4.ip_forward"
            sed -i.bak "s/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf
            rm -f /etc/sysctl.conf.bak
        else
            echo "DEVOP-781: APPENDING net.ipv4.ip_forward"
            echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
        fi
        echo "DEVOP-781: restarting network"
        systemctl restart network
        if [ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]; then
            echo "DEVOP-781: OK -> $(sysctl net.ipv4.ip_forward)"
        else
            echo "Still broken after network restart -> $(sysctl net.ipv4.ip_forward)"
            exit 1
        fi
    fi
}

dnsAutoConfigure() {
    if [ ! -f /etc/init.d/dns-auto-configure ]; then
        echo "dns-auto-configure - Cannot find dns-auto-configure service. Installing now..."
        bash -c "${currentScriptDir}/dns-auto-configure-setup.sh"
    else
        echo "dns-auto-configure - found service, no need to install."
    fi
}

provisioningSteps() {
    if ! command -v aws > /dev/null; then
      echo "Installing AWS CLI..."
      curl --fail -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
      unzip -u -q awscliv2.zip
      ./aws/install --bin-dir /usr/bin --update
    fi
    aws --version
    if ! command -v jq > /dev/null; then
      echo "Installing jq..."
      yum install -q -y jq
    fi
    jq --version
    echo "Installing Docker..."
    if ! command -v docker > /dev/null; then
      amazon-linux-extras install -q -y docker
      systemctl enable docker
      systemctl start docker
    fi
    docker --version
    echo "Installing Postgres..."
    if ! command -v psql > /dev/null; then
      amazon-linux-extras install -q -y postgresql11
    fi
    psql --version
    echo "Installing docker-compose..."
    if ! command -v docker-compose > /dev/null; then
      curl --fail -sSL "https://github.com/docker/compose/releases/download/1.28.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    docker-compose --version
}

dockerPullPlatform() {
  local awsKey=$(echo ${AWS_ECR_CREDENTIALS//:*})
  local awsSec=$(echo ${AWS_ECR_CREDENTIALS//*:})
  local platformEcrImageRegistry=$(echo $PLATFORM_ECR_IMAGE | cut -d/ -f 1)
  local platformEcrImageRegion=$(echo $PLATFORM_ECR_IMAGE | cut -d. -f 4)
  echo "Attempting to login to the ECR repo '${platformEcrImageRegistry}'..."
  AWS_ACCESS_KEY_ID=$awsKey AWS_SECRET_ACCESS_KEY=$awsSec \
      aws ecr get-login-password --region "${platformEcrImageRegion}" | \
      docker login --username AWS --password-stdin "${platformEcrImageRegistry}"
  docker pull ${PLATFORM_ECR_IMAGE}
}

setupPlatformScripts() {
    docker create --name tmp-platform-init ${PLATFORM_ECR_IMAGE} bash
    docker cp tmp-platform-init:/docker-compose $INSTALL_USER_HOME/docker-compose
    docker rm tmp-platform-init
    chown -R $INSTALL_USER $INSTALL_USER_HOME/docker-compose
    cd $INSTALL_USER_HOME/docker-compose || exit 1
    make
}

# Main

echo "Hello from $(whoami) in $(pwd)"
checkVars

# Run as root to setup instance
if [[ $EUID -eq 0 ]]; then
    echo "Setting up Instance as root user..."
    echo "Preemptively adding docker group and giving $INSTALL_USER membership..."
    [ $(getent group docker) ] || groupadd -r docker
    usermod -aG docker $INSTALL_USER
    activateNetIpForward
    dnsAutoConfigure
    provisioningSteps
else
  echo "Run me as root to setup this instance."
  echo "Pulling Platform without setting up instance..."
fi

echo "Setting up Platform..."
dockerPullPlatform
setupPlatformScripts
