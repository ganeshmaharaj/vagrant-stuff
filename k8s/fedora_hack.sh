#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

echo "Disabling firewalld..."
if $(sudo systemctl is-active firewalld > /dev/null); then
  sudo systemctl disable --now firewalld
fi

source /etc/os-release

if [ "${VERSION_ID}" == "32" ]; then
	sudo dnf install -y grubby
	sudo grubby \
	  --update-kernel=ALL \
	  --args="systemd.unified_cgroup_hierarchy=0"
fi
