#!/bin/sh

# Set debug option
set -o errexit
set -o nounset
set -o xtrace

# Update apt local cache
apt update

# Install required packages
apt install --yes ca-certificates curl unzip jq

# Determine CPU architecture
CPU_ARCH=$(uname -m)

if [ "${CPU_ARCH}" = "x86_64" ]
then

    echo "Get download URL and download zip file ..."
    DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/bitwarden/clients/releases" | jq -r ".[] | select(.name | startswith(\"CLI\")) | .assets[] | select(.name==\"bw-linux-${BW_CLI_VERSION}.zip\") | .browser_download_url")
    curl --location --output "bw-linux-${BW_CLI_VERSION}.zip" "${DOWNLOAD_URL}"

    echo "Verifying file integrity..."
    ACTUAL_CHECKSUM=$(sha256sum "bw-linux-${BW_CLI_VERSION}.zip" | awk '{print $1}')
    SHA256SUMS_URL=$(curl -s "https://api.github.com/repos/bitwarden/clients/releases" | jq -r ".[] | select(.name | startswith(\"CLI\")) | .assets[] | select(.name==\"bw-linux-sha256-${BW_CLI_VERSION}.txt\") | .browser_download_url")
    SHA256SUM=$(curl --location -s "$SHA256SUMS_URL")

    # Compare checksums to ensure integrity
    if [ "${SHA256SUM}" = "${ACTUAL_CHECKSUM}" ]
    then 
        echo "Checksum verified. File integrity is intact."
    else
        echo "Checksum verification failed. The download file may be corrupted."
        exit 1
    fi

    # Unzip downloaded Bitwarden CLI 
    unzip bw-linux-${BW_CLI_VERSION}.zip

    # Make Bitwarden CLI executable and move to binary to $PATH
    chmod +x bw
    mv bw /usr/local/bin/bw

    # Cleanup all unnecessary files and packages
    rm -rfv bw-linux-${BW_CLI_VERSION}.zip
fi

# If Arm64 architecture, install "npm" and then use npm to install "@bitwarden/cli" in the version identified by ${BW_CLI_VERSION}
if [ "${CPU_ARCH}" = "aarch64" ]
then
    apt install --yes npm
    npm install -g "@bitwarden/cli@${BW_CLI_VERSION}"

    # Uninstall npm and just leave the bitwarden CLI.
    npm uninstall npm -g
fi

# Cleanup all unnecessary files and packages
apt remove --yes unzip jq
apt clean autoclean
apt autoremove --yes
rm -rf /var/lib/{apt,dpkg,cache,log}/

# Create Bitwarden CLI service user incl. home directory -> rootless container
groupadd --gid 7001 bwcli
useradd -c "Service user for Bitwarden cli" --home-dir /bwcli --gid 7001 --no-user-group --no-create-home --shell /sbin/nologin --uid 7001 bwcli
mkdir /bwcli
chown bwcli:bwcli -R /bwcli
chmod 700 -R /bwcli