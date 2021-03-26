#!/usr/bin/env bash

set -euxo pipefail

# this would be PWD if running "curl s3Url | bash"
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]:-}" )" >/dev/null 2>&1 && pwd )"
main_name='dns-auto-configure'

download_from_s3() {
    curl --connect-timeout 2 -q -f --retry-delay 2 --retry 5 \
        -o "/tmp/${1}" \
        "https://s3.amazonaws.com/examples.datameer.com/ec2-util-scripts/dns-auto-config-scripts/${1}"
}
prepare_file() {
    local file_name=$1 target=$2
    if [ -f "${script_dir}/${file_name}" ]; then
        cp "${script_dir}/${file_name}" "${target}"
    elif [ -f "/tmp/${file_name}" ]; then
        cp "/tmp/${file_name}" "${target}"
    elif download_from_s3 "${file_name}"; then
        cp "/tmp/${file_name}" "${target}"
    else
        echo "File '${file_name}' neither in script directory, nor could it be downloaded. Failing..."
        return 1
    fi
    chmod +x "${target}"
}
if [[ $EUID -ne 0 ]]; then
    echo "This script needs to be run as root or with sudo"
    exit 1
fi
prepare_file ${main_name}-script "/usr/bin/${main_name}"
prepare_file ${main_name}-service "/etc/init.d/${main_name}"
# Enable and Start ${main_name} service
pidof systemd && systemctl restart ${main_name}.service || service ${main_name} restart
pidof systemd && systemctl enable  ${main_name}.service || chkconfig ${main_name} on