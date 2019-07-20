#!/usr/bin/env bash

echo "this is a network hack for generic/ubuntuXX boxes.."
sudo sed -i "/nameservers/d" /etc/netplan/01-netcfg.yaml
sudo sed -i "/addresses/d" /etc/netplan/01-netcfg.yaml
sudo sed -i "s/DNS=.*/DNS=/g" /etc/systemd/resolved.conf
sudo sed -i "s/DNSSEC=.*/DNSSEC=no/g" /etc/systemd/resolved.conf
sudo netplan generate
sudo netplan apply
sudo systemctl restart systemd-networkd.service systemd-resolved.service
