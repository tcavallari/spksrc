SPK_NAME = gitlab
SPK_VERS = 7.1
SPK_REV = 0
SPK_ICON = src/gitlab.png
DSM_UI_DIR = app

DEPENDS  =
SPK_DEPENDS = 

MAINTAINER = SynoCommunity
DESCRIPTION = GitLab Community Edition \(CE\) is open source software to collaborate on code. Create projects and git repositories, manage access and do code reviews. GitLab CE is on-premises software that you can install and use on your server\(s\).
RELOAD_UI = yes
DISPLAY_NAME = Gitlab
CHANGELOG = ""

HOMEPAGE   = https://about.gitlab.com/
LICENSE    =
HELPURL    = http://synocommunity.com/help/gitlab

INSTALLER_SCRIPT = src/installer.sh
SSS_SCRIPT       = src/dsm-control.sh

INSTALL_PREFIX = /usr/local/$(SPK_NAME)

COPY_TARGET = nop
POST_STRIP_TARGET = gitlab_extra_install

DEBIAN_ARCH =

ifeq ($(findstring $(ARCH),bromolow cedarview evansport x86),$(ARCH))
DEBIAN_ARCH = amd64
endif

ifeq ($(strip $(DEBIAN_ARCH)),)
$(error Arch $(ARCH) not supported)
endif


include ../../mk/spksrc.spk.mk

.PHONY: gitlab_extra_install
gitlab_extra_install: 
	install -m 755 -d $(STAGING_DIR)/var
	install -m 755 -d $(STAGING_DIR)/etc
	debootstrap --foreign --arch $(DEBIAN_ARCH) wheezy $(STAGING_DIR)/var/chroottarget "http://ftp.debian.org/debian"
	install -m 644 src/sources.list $(STAGING_DIR)/var/chroottarget/etc/apt/sources.list.default
	install -m 644 src/preferences $(STAGING_DIR)/var/chroottarget/etc/apt/preferences.default
	install -m 644 src/policy-rc.d $(STAGING_DIR)/var/chroottarget/usr/sbin/policy-rc.d
	install -m 755 src/bootstrap.sh $(STAGING_DIR)/var/chroottarget/bootstrap.sh
	install -m 755 -d $(STAGING_DIR)/var/chroottarget/etc/gitlab
	install -m 644 src/cfg/gitlab.yml.default $(STAGING_DIR)/var/chroottarget/etc/gitlab/gitlab.yml.default
	install -m 644 src/cfg/application.rb.default $(STAGING_DIR)/var/chroottarget/etc/gitlab/application.rb.default
	install -m 644 src/cfg/unicorn.rb.default $(STAGING_DIR)/var/chroottarget/etc/gitlab/unicorn.rb.default
	install -m 644 src/cfg/database.yml.default $(STAGING_DIR)/var/chroottarget/etc/gitlab/database.yml.default
	install -m 644 src/cfg/resque.yml.default $(STAGING_DIR)/var/chroottarget/etc/gitlab/resque.yml.default
	install -m 644 src/cfg/gitlab.default $(STAGING_DIR)/var/chroottarget/etc/gitlab/gitlab.default
	install -m 644 src/cfg/logrotate.default $(STAGING_DIR)/var/chroottarget/etc/gitlab/logrotate.default
	install -m 644 src/cfg/nginx.default $(STAGING_DIR)/var/chroottarget/etc/gitlab/nginx.default
	install -m 644 src/cfg/gitlab-httpd.conf $(STAGING_DIR)/etc/gitlab-httpd.conf

