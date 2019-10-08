#!/bin/bash
set -e
cd /root/docker

# Update packages and set up the basics.
sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list
apt-get update
apt-get -y upgrade
apt-get install -y software-properties-common curl git htop man unzip vim wget ack net-tools
# Debugging tools
apt-get install -y gdb strace tcpdump linux-perf xxd bsdmainutils

# Shell customizations.
# Enable core dumps.
echo "ulimit -c unlimited" >> /root/.bashrc
