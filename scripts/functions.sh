# (C) Datadog, Inc. 2010-2016
# All rights reserved
# Licensed under Simplified BSD License (see LICENSE)
# Parts taken from the datadog installation script at https://s3.amazonaws.com/dd-agent/scripts/install_script.sh

# Used in the `process.sh` scripts below.
export PU_LOCAL_ROOT="${PU_LOCAL_ROOT:-/config-files/platform-utils}"

die() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

info() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

#######################################
# OS/Distro Detection
# Try lsb_release, fallback with /etc/issue then uname command
# Globals:
#   KNOWN_DISTRIBUTION
#   DISTRIBUTION
#   OS
# Arguments:
#   None
#######################################
distro_detection() {
  [ ! "${DISTRIBUTION+1}" ] || return 0 # DISTRIBUTION already set
  KNOWN_DISTRIBUTION="(Debian|Ubuntu|RedHat|CentOS|openSUSE|Amazon|Arista|SUSE)"
  DISTRIBUTION=$(lsb_release -d 2>/dev/null | grep -Eo $KNOWN_DISTRIBUTION  || grep -Eo $KNOWN_DISTRIBUTION /etc/issue 2>/dev/null || grep -Eo $KNOWN_DISTRIBUTION /etc/Eos-release 2>/dev/null || grep -m1 -Eo $KNOWN_DISTRIBUTION /etc/os-release 2>/dev/null || uname -s)

  if [ "$DISTRIBUTION" = "Darwin" ]; then
    printf "\033[31mThis script does not support installing on the Mac.\n
    Please use the 1-step script available at https://app.datadoghq.com/account/settings#agent/mac.\033[0m\n"
    exit 1;
  elif [ -f /etc/debian_version ] || [ "$DISTRIBUTION" == "Debian" ] || [ "$DISTRIBUTION" == "Ubuntu" ]; then
    OS="Debian"
  elif [ -f /etc/redhat-release ] || [ "$DISTRIBUTION" == "RedHat" ] || [ "$DISTRIBUTION" == "CentOS" ] || [ "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
  # Some newer distros like Amazon may not have a redhat-release file
  elif [ -f /etc/system-release ] || [ "$DISTRIBUTION" == "Amazon" ]; then
    OS="RedHat"
  # Arista is based off of Fedora14/18 but do not have /etc/redhat-release
  elif [ -f /etc/Eos-release ] || [ "$DISTRIBUTION" == "Arista" ]; then
    OS="RedHat"
  # openSUSE and SUSE use /etc/SuSE-release or /etc/os-release
  elif [ -f /etc/SuSE-release ] || [ "$DISTRIBUTION" == "SUSE" ] || [ "$DISTRIBUTION" == "openSUSE" ]; then
    OS="SUSE"
  fi
}

#######################################
# Root user detection
# Globals:
#   SUDO_CMD
# Arguments:
#   None
#######################################
root_detection() {
  [ ! "${SUDO_CMD+1}" ] || return 0 # SUDO_CMD already set
  if [ "$(echo "$UID")" = "0" ]; then
    SUDO_CMD=''
  else
    SUDO_CMD='sudo'
  fi
}

#######################################
# Generic ansible installation
#######################################
install_ansible() {
  root_detection
  distro_detection
  if command -v ansible > /dev/null 2>&1; then
    info "Ansible already installed. Doing nothing..."
    ansible --version
    return 0
  fi
  # Install the necessary package sources
  if [ "$DISTRIBUTION" = "Amazon" ]; then
    printf "\033[34m* Installing ansible on '$DISTRIBUTION'\n\033[0m\n"
    $SUDO_CMD amazon-linux-extras install ansible2 -y
  elif [ "$DISTRIBUTION" = "CentOS" ]; then
    printf "\033[34m* Installing ansible on '$DISTRIBUTION'\n\033[0m\n"
    $SUDO_CMD yum -y clean metadata
    $SUDO_CMD yum -y install ansible
  elif [ "$DISTRIBUTION" = "Ubuntu" ]; then
    printf "\033[34m* Installing ansible on '$DISTRIBUTION'\n\033[0m\n"
    $SUDO_CMD apt update -y
    $SUDO_CMD apt install -y software-properties-common
    $SUDO_CMD apt-add-repository --yes --update ppa:ansible/ansible
    $SUDO_CMD apt install -y ansible
  else
    printf "\033[31mYour OS or distribution are not supported by this script.\033[0m\n"
    exit;
  fi
}

curl_ec2() {
  local ec2MetaUrl='http://169.254.169.254/latest'
  [ -n "${TOKEN:-}" ] || TOKEN=$(curl -s -X PUT $ec2MetaUrl -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  curl -s --connect-timeout 2 -q -f --retry-delay 2 --retry 5 -H "X-aws-ec2-metadata-token: $TOKEN" $ec2MetaUrl/$1
}

init_instance_tags() {
  if [ -z "${INSTANCE_TAGS:-}" ]; then
    export INSTANCE_ID=$(curl_ec2 meta-data/instance-id)
    export AWS_REGION=$(curl_ec2 meta-data/placement/region)
    export INSTANCE_TAGS="$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" --region $AWS_REGION)"
  fi
}

get_instance_tag() {
  init_instance_tags
  echo $INSTANCE_TAGS| jq -r --arg tag $1 -r '.Tags[]|select(.Key == $tag)|.Value'
}

# get a property value based on its name from a hadoop config xml
get_hadoop_property() {
  local key=$1
  local file=$2
  xmllint --xpath "/configuration/*[name='$key']/value/text()" $file
}

#######################################
# Determine a instance usage
# e.g. emr, spotlight, etc...
#######################################
component_detection() {
  export PLAYBOOK_COMPONENT PLAYBOOK_NAME
  # https://docs.aws.amazon.com/emr/latest/ManagementGuide/emr-fs.html
  if command -v emrfs > /dev/null 2>&1; then
    local node_type
    node_type=$(get_instance_tag 'aws:elasticmapreduce:instance-group-role')
    info "Determined EMR instance of node type '$node_type'..."
    PLAYBOOK_COMPONENT='emr'
    PLAYBOOK_NAME="${node_type,,}-node"
    return 0
  fi
  # TODO(sboardwell): let us think of a better way to determine spotlight installations
  if [ -f /home/ec2-user/docker-compose/startup.sh ]; then
    info "Determined Spotlight instance..."
    PLAYBOOK_COMPONENT='spotlight'
    PLAYBOOK_NAME='spotlight'
    return 0
  fi
  info "Could not determine instance. Using default..."
  PLAYBOOK_COMPONENT='default'
  PLAYBOOK_NAME='default'
}
