#!/bin/bash
set -e # die on errors
set -vx # print commands before executing them

# Setup steps adapted from here:
# https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/installation.md

USER=git
USER_UID=1028
USER_GID=100
USER_HOME=/var/services/homes/git
GITLAB_HOME=${USER_HOME}/gitlab
POSTGRESQL_PORT=15432

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
service redis-server stop

echo Building ruby...
aptitude remove -y ruby1.8
mkdir /tmp/ruby && cd /tmp/ruby
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.1/ruby-2.1.2.tar.gz | tar xz
cd ruby-2.1.2/
./configure --disable-install-rdoc
make -j3
make install
gem install bundler --no-ri --no-rdoc

echo Creating git user...
adduser --disabled-login --gecos "GitLab" --home ${USER_HOME} --uid ${USER_UID} --gid ${USER_GID} ${USER}

echo Installing PostgreSql
aptitude install -y postgresql-9.1 postgresql-client libpq-dev
sudo -u postgres psql -d template1 <<END
CREATE USER git CREATEDB;
CREATE DATABASE gitlabhq_production OWNER git;
\q
END
service postgresql stop

sed -i "s/^\([[:space:]]*port[[:space:]]*=[[:space:]]*\)[[:digit:]][[:digit:]]*\(.*\)$/\1$POSTGRESQL_PORT\2/" /etc/postgresql/9.1/main/postgresql.conf

echo Installing Gitlab...
cd ${USER_HOME}
sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 7-1-stable gitlab
cd ${GITLAB_HOME}
sudo -u git -H cp /etc/gitlab/gitlab.yml.default config/gitlab.yml
sudo -u git -H cp /etc/gitlab/application.rb.default config/application.rb
sudo -u git -H cp /etc/gitlab/unicorn.rb.default config/unicorn.rb
sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

sudo -u git -H cp /etc/gitlab/database.yml.default config/database.yml
sudo -u git -H chmod go-rwx config/database.yml

chown -R git log/
chown -R git tmp/
chmod -R u+rwX log/
chmod -R u+rwX tmp/
chmod -R u+rwX public/uploads
sudo -u git -H mkdir ${USER_HOME}/gitlab-satellites
chmod u+rwx,g=rx,o-rwx ${USER_HOME}/gitlab-satellites

sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "example@example.com"
sudo -u git -H git config --global core.autocrlf input

echo Installing gems...
cd ${GITLAB_HOME}
sudo -u git -H bundle install --deployment --without development test mysql aws

