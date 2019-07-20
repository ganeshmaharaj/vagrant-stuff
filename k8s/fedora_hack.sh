#!/bin/bash

set -o errexit
set -o nounset

echo "Disabling firewalld..."
sudo systemctl stop firewalld
sudo systemctl disable firewalld
