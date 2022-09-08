#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

echo "Disabling firewalld..."
if $(sudo systemctl is-active firewalld > /dev/null); then
  sudo systemctl disable --now firewalld
fi
