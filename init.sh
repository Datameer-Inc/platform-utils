#!/usr/bin/env bash
#
# Init script to download latest released version of this repository

set -euo pipefail

repo_name='spotlight-utils'
repo_url="https://github.com/Datameer-Inc/${repo_name}"
latest_url="${repo_url}/releases/latest"
default_path="/tmp/${repo_name}"
base_path="${UTILS_INSTALL_PATH:-${default_path}}"

die() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

info() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

determine_latest_version() {
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
    install_path="${base_path}/${release}"
    latest_path="${base_path}/latest"
}

download_and_extract() {
    if [ -d "${install_path}" ]; then
        info "Install path already exists. No need to install..."
    elif [ -e "${install_path}" ]; then
        die "Install path already exists but not a directory."
    else
        info "Downloading '${download_url}' to directory '${install_path}'"
        mkdir -p "${install_path}"
        curl -fsSL -o "${install_path}/${download_file}" "${download_url}"
        pushd "${install_path}"
            info "Extracting '${download_file}'"
            tar xzf "${download_file}" --strip 1
        popd
        info "Setting symlink '${install_path}' -> '${latest_path}'"
        rm -f "${latest_path}"
        ln -sf "${install_path}" "${latest_path}"
    fi
}

determine_latest_version
download_and_extract
tools_script="${latest_path}/process-tools.sh"
if [ ! -f "${tools_script}" ]; then
    die "Could not find ${tools_script}"
else
    "${tools_script}"
fi