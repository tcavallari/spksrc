#!/bin/bash
set -e # die on errors
set -vx # print commands before executing them

# Setup steps adapted from here:
# https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/installation.md

echo Updating base system...
aptitude update
aptitude upgrade -y

echo Setting up locale...
aptitude install -y locales
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
LANG=en_US.UTF-8 locale-gen --purge en_US.UTF-8
echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US.UTF-8"\n' > /etc/default/locale

echo Setting up timezone...
echo "Europe/Rome" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

echo Installing dependencies...
aptitude install -y sudo vim nano git-core
aptitude install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate python-docutils
