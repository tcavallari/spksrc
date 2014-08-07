#!/bin/bash
set -e # die on errors
set -x # print commands before executing them

# Setup steps adapted from here:
# https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/install/installation.md

source bootstrap_variables.sh

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
aptitude install -y sudo vim nano git-core gettext
aptitude install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate python-docutils
service redis-server stop

sed -i "s/^\([[:space:]]*port[[:space:]]*\)[[:digit:]][[:digit:]]*\(.*\)$/\1${REDIS_PORT}\2/" /etc/redis/redis.conf

service redis-server start

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
adduser --disabled-login --gecos "GitLab" --home ${GITLAB_USER_HOME} --uid ${GITLAB_USER_UID} --gid ${GITLAB_USER_GID} ${GITLAB_USER}

echo Installing PostgreSql
aptitude install -y postgresql-9.1 postgresql-client libpq-dev
sudo -u postgres psql -d template1 <<END
CREATE USER git CREATEDB;
CREATE DATABASE gitlabhq_production OWNER git;
\q
END

service postgresql stop

sed -i "s/^\([[:space:]]*port[[:space:]]*=[[:space:]]*\)[[:digit:]][[:digit:]]*\(.*\)$/\1${POSTGRESQL_PORT}\2/" /etc/postgresql/9.1/main/postgresql.conf

service postgresql start

echo Installing Gitlab...
cd ${GITLAB_USER_HOME}
sudo -u ${GITLAB_USER} -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 7-1-stable gitlab

cd ${GITLAB_ROOT}

envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/gitlab.yml.template > /etc/gitlab/gitlab.yml.default
sudo -u ${GITLAB_USER} -H cp /etc/gitlab/gitlab.yml.default config/gitlab.yml

envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/application.rb.template > /etc/gitlab/application.rb.default
sudo -u ${GITLAB_USER} -H cp /etc/gitlab/application.rb.default config/application.rb

envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/unicorn.rb.template > /etc/gitlab/unicorn.rb.default
sudo -u ${GITLAB_USER} -H cp /etc/gitlab/unicorn.rb.default config/unicorn.rb

envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/resque.yml.template > /etc/gitlab/resque.yml.default
sudo -u ${GITLAB_USER} -H cp /etc/gitlab/resque.yml.default config/resque.yml

sudo -u ${GITLAB_USER} -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb

envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/database.yml.template > /etc/gitlab/database.yml.default
sudo -u ${GITLAB_USER} -H cp /etc/gitlab/database.yml.default config/database.yml
sudo -u ${GITLAB_USER} -H chmod go-rwx config/database.yml

chown -R ${GITLAB_USER} log/
chown -R ${GITLAB_USER} tmp/
chmod -R u+rwX log/
chmod -R u+rwX tmp/
chmod -R u+rwX public/uploads
sudo -u ${GITLAB_USER} -H mkdir ${GITLAB_USER_HOME}/gitlab-satellites
chmod u+rwx,g=rx,o-rwx ${GITLAB_USER_HOME}/gitlab-satellites

sudo -u ${GITLAB_USER} -H git config --global user.name "GitLab"
sudo -u ${GITLAB_USER} -H git config --global user.email "${GITLAB_EMAIL_FROM}"
sudo -u ${GITLAB_USER} -H git config --global core.autocrlf input

echo Installing gems...
cd ${GITLAB_ROOT}
sudo -u ${GITLAB_USER} -H bundle install --deployment --without development test mysql aws

echo Installing Gitlab shell...
cd ${GITLAB_ROOT}
sudo -u ${GITLAB_USER} -H bundle exec rake gitlab:shell:install[v1.9.6] REDIS_URL=redis://localhost:${REDIS_PORT} RAILS_ENV=production

envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/shell_config.yml.template > /etc/gitlab/shell_config.yml.default
sudo -u ${GITLAB_USER} -H cp /etc/gitlab/shell_config.yml.default ${GITLAB_USER_HOME}/gitlab-shell/config.yml

echo Populating database...
sudo -u ${GITLAB_USER} -H bundle exec rake gitlab:setup RAILS_ENV=production <<END
yes
END

echo Setting up startup scripts...
cp lib/support/init.d/gitlab /etc/init.d/gitlab
envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/gitlab.template > /etc/gitlab/gitlab.default
cp /etc/gitlab/gitlab.default /etc/default/gitlab
update-rc.d gitlab defaults 21

envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/logrotate.template > /etc/gitlab/logrotate.default
cp /etc/gitlab/logrotate.default /etc/logrotate.d/gitlab

sudo -u ${GITLAB_USER} -H bundle exec rake gitlab:env:info RAILS_ENV=production
sudo -u ${GITLAB_USER} -H bundle exec rake assets:precompile RAILS_ENV=production

echo Starting service...
service gitlab restart

echo Installing and configuring Nginx...
aptitude install -y nginx
envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/nginx.template > /etc/gitlab/nginx.default
envsubst "$GITLAB_ALL_VARIABLE_NAMES" < /etc/gitlab/gitlab-httpd-proxy.template > /etc/gitlab/gitlab-httpd-proxy.conf
cp /etc/gitlab/nginx.default /etc/nginx/sites-available/gitlab
ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
rm /etc/nginx/sites-enabled/default

echo Setup complete, stopping all services...
service nginx stop
service gitlab stop
service redis-server stop
service postgresql stop

