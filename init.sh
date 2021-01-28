#!/usr/bin/env bash
#
# Init script to download latest released version of this repository

set -euo pipefail

repo_url='https://github.com/Datameer-Inc/spotlight-utils'
latest_url="${repo_url}/releases/latest"
root_dir="${PU_BASE_INSTALL_DIR:-/tmp}"

function die() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

function info() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

function download_and_extract() {
  if ! latest_release_url=$(curl -fsSLI -o /dev/null -w %{url_effective} "${latest_url}"); then
    die "Problem getting ${latest_url}"
  fi
  if [[ $latest_release_url =~ releases/tag ]]; then
    release="${latest_release_url//*\//}"
  else
    release='master'
  fi
  download_file="${release}.tar.gz"
  download_url="${repo_url}/archive/${download_file}"
  install_path="${root_dir}/spotlight-utils/${release}"
  latest_path="${root_dir}/spotlight-utils/latest"
  if [ -d "${install_path}" ]; then
    info "Install path already exists. No need to install..."
  elif [ -e "${install_path}" ]; then
    die "Install path already exists but not a directory."
  else
    info "Deleting any previous installations at '$(dirname ${install_path})'"
    rm -rf "$(dirname ${install_path})"
    info "Downloading '${download_url}' to directory '${install_path}'"
    mkdir -p "${install_path}"
    curl -fsSL -o "${install_path}/${download_file}" "${download_url}"
    cd "${install_path}"
    info "Extracting '${download_file}'"
    tar xzf "${download_file}" --strip 1
    cd -
    info "Setting symlink '${install_path}' -> '${latest_path}'"
    rm -f "${latest_path}"
    ln -sf "${install_path}" "${latest_path}"
  fi
}

download_and_extract
tools_script="${latest_path}/process-tools.sh"
if [ ! -f "${tools_script}" ]; then
  die "Could not find ${tools_script}"
else
  "${tools_script}"
fi
