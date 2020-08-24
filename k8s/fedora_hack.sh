#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

echo "Disabling firewalld..."
sudo systemctl stop firewalld
sudo systemctl disable firewalld

source /etc/os-release

if [ "${VERSION_ID}" == "32" ]; then
	sudo dnf install -y grubby
	sudo grubby \
	  --update-kernel=ALL \
	  --args="systemd.unified_cgroup_hierarchy=0"
fi
