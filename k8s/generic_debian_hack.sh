#!/usr/bin/env bash

echo "this is a network hack for generic/debianXX boxes.."
sudo sed -i "/dns-nameserver/d" /etc/network/interfaces
sudo sed -i "s/#DNSSEC=.*/DNSSEC=no/g" /etc/systemd/resolved.conf
# The IP below is that of libvirt network gateway
sudo bash -c 'echo "nameserver 10.248.2.1" > /etc/resolvconf/resolv.conf.d/original'
sudo bash -c 'echo "nameserver 10.248.2.1" > /run/resolvconf/resolv.conf'
sudo bash -c 'echo "nameserver 10.248.2.1" > /etc/resolv.conf'
