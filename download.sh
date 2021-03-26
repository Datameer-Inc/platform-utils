#!/usr/bin/env bash
#
# Init script to download latest released version of this repository

set -euo pipefail

repoUrl='https://github.com/Datameer-Inc/platform-utils'
latestUrl="${repoUrl}/releases/latest"
rootDir="${PU_BASE_INSTALL_DIR:-/tmp}"

function die() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

function info() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

#######################################
# Get latest platform-utils release URL
# Globals:
#   None
# Arguments:
#   None
#######################################
function getLatestRelease() {
  if ! latestReleaseUrl=$(curl -fsSLI -o /dev/null -w %{url_effective} "${latestUrl}"); then
    die "Problem getting ${latestUrl}"
  fi
  if [[ $latestReleaseUrl =~ releases/tag ]]; then
    latestRelease="${latestReleaseUrl//*\//}"
  else
    latestRelease='master'
  fi
}

#######################################
# Download and Extract Platform Utils Release tar
# Globals:
#   CUSTOM_RELEASE
#   PU_BASE_INSTALL_DIR
# Arguments:
#   None
#######################################
function downloadAndExtract() {
  getLatestRelease
  release=${CUSTOM_RELEASE:-$latestRelease}
  [ -n $release ] || die "Couldn't find platform-utils release."
  downloadFile="${release}.tar.gz"
  downloadUrl="${repoUrl}/archive/${downloadFile}"
  installPath="${rootDir}/platform-utils/${release}"
  latestPath="${rootDir}/platform-utils/latest"
  if [ -d "${installPath}" ]; then
    info "Install path already exists. No need to install..."
  elif [ -e "${installPath}" ]; then
    die "Install path already exists but not a directory."
  else
    info "Deleting any previous installations at '$(dirname ${installPath})'"
    rm -rf "$(dirname ${installPath})"
    info "Downloading '${downloadUrl}' to directory '${installPath}'"
    mkdir -p "${installPath}"
    curl -fsSL -o "${installPath}/${downloadFile}" "${downloadUrl}"
    cd "${installPath}"
    info "Extracting '${downloadFile}'"
    tar xzf "${downloadFile}" --strip 1
    cd -
    info "Setting symlink '${installPath}' -> '${latestPath}'"
    rm -f "${latestPath}"
    ln -sf "${installPath}" "${latestPath}"
  fi
}

# Main

downloadAndExtract
