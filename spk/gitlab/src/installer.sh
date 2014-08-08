#!/bin/sh

# Package
PACKAGE="gitlab"
DNAME="Gitlab"

# Others
INSTALL_DIR="/usr/local/${PACKAGE}"
CHROOTTARGET=`realpath ${SYNOPKG_PKGDEST}/var/chroottarget`
PATH="${INSTALL_DIR}/bin:${INSTALL_DIR}/env/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin"
CHROOT_PATH="/usr/local/bin:/usr/bin:/bin"
TMP_DIR="${SYNOPKG_PKGDEST}/../../@tmp"
VARIABLES_FILE=${CHROOTTARGET}/bootstrap_variables.sh

preinst ()
{
    # Check provided username
    if [ "${SYNOPKG_PKG_STATUS}" = "INSTALL" ]; then
        for usr in root admin guest; do
            if [ "${wizard_gitlab_user}" = "$usr" ]; then
                echo "Usernames root, admin and guest are not allowed."
                exit 1
            fi
        done
    fi
    
    exit 0
}

postinst ()
{
    # Link
    ln -s ${SYNOPKG_PKGDEST} ${INSTALL_DIR}

    # Debootstrap second stage in the background and configure the chroot environment
    if [ "${SYNOPKG_PKG_STATUS}" != "UPGRADE" ]; then
        # Create user if necessary
        if ! id "${wizard_gitlab_user}" > /dev/null 2>&1; then
            # Empty password
            synouser --add "${wizard_gitlab_user}" "" "GitLab" 0 "" 0
            # Disable password login
            cp -p /etc/shadow /etc/shadow.bak
            sed -i 's_^\('"${wizard_gitlab_user}"':\)[^:]*\(:.*\)$_\1*\2_' /etc/shadow
        fi
        
        # Set the shell to /bin/sh if it was /sbin/nologin
        cp -p /etc/passwd /etc/passwd.bak
        sed -i 's_^\('"${wizard_gitlab_user}"':[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\)/sbin/nologin$_\1/bin/sh_' /etc/passwd

        REAL_HOME=`realpath /var/services/homes/"${wizard_gitlab_user}"`
        # The home folder must exist
        if [ ! -d ${REAL_HOME} ]; then
            exit 1
        fi
        # Prepare variables file
        echo export GITLAB_USER="${wizard_gitlab_user}" >> ${VARIABLES_FILE}
        echo export GITLAB_USER_UID=`id -u "${wizard_gitlab_user}"` >> ${VARIABLES_FILE}
        echo export GITLAB_USER_HOME="${REAL_HOME}" >> ${VARIABLES_FILE}
        echo 'export GITLAB_ROOT=${GITLAB_USER_HOME}/gitlab' >> ${VARIABLES_FILE}
        echo export GITLAB_EMAIL_FROM="${wizard_gitlab_email_from}" >> ${VARIABLES_FILE}
        echo export GITLAB_FQDN="${wizard_gitlab_fqdn}" >> ${VARIABLES_FILE}
        echo export GITLAB_RELATIVE_ROOT="${wizard_gitlab_relative_root}" >> ${VARIABLES_FILE}

        ( 
            set -e
            # Finish bootstrapping
            chroot ${CHROOTTARGET}/ /debootstrap/debootstrap --second-stage
            chmod 666 ${CHROOTTARGET}/dev/null
            chmod 666 ${CHROOTTARGET}/dev/tty
            chmod 777 ${CHROOTTARGET}/tmp
            mv ${CHROOTTARGET}/etc/apt/sources.list.default ${CHROOTTARGET}/etc/apt/sources.list
            mv ${CHROOTTARGET}/etc/apt/preferences.default ${CHROOTTARGET}/etc/apt/preferences
            cp /etc/hosts /etc/hostname /etc/resolv.conf ${CHROOTTARGET}/etc/

            # Make sure we don't mount twice
            grep -q "${CHROOTTARGET}/proc " /proc/mounts || mount -t proc proc ${CHROOTTARGET}/proc
            grep -q "${CHROOTTARGET}/sys " /proc/mounts || mount -t sysfs sys ${CHROOTTARGET}/sys
            grep -q "${CHROOTTARGET}/dev " /proc/mounts || mount -o bind /dev ${CHROOTTARGET}/dev
            grep -q "${CHROOTTARGET}/dev/pts " /proc/mounts || mount -o bind /dev/pts ${CHROOTTARGET}/dev/pts
            grep -q "${CHROOTTARGET}${REAL_HOME} " /proc/mounts || mount -o bind ${REAL_HOME} ${CHROOTTARGET}${REAL_HOME}

            # Setup Gitlab and dependencies
            chroot ${CHROOTTARGET}/ /bin/bash /bootstrap.sh
            echo "All done!"

            touch ${INSTALL_DIR}/var/installed
        ) > ${INSTALL_DIR}/var/install.log 2>&1

        # Unmount
        umount ${CHROOTTARGET}/dev/pts
        umount ${CHROOTTARGET}/dev
        umount ${CHROOTTARGET}/sys
        umount ${CHROOTTARGET}/proc
        umount ${CHROOTTARGET}${REAL_HOME}
    fi

    exit 0
}

preuninst ()
{
    exit 0
}

postuninst ()
{
    # Remove link
    rm -f ${INSTALL_DIR}

    exit 0
}

preupgrade ()
{
    # Save some stuff
    rm -fr ${TMP_DIR}/${PACKAGE}
    mkdir -p ${TMP_DIR}/${PACKAGE}
    mv ${INSTALL_DIR}/var ${TMP_DIR}/${PACKAGE}/

    exit 0
}

postupgrade ()
{
    # Restore some stuff
    rm -fr ${INSTALL_DIR}/var
    mv ${TMP_DIR}/${PACKAGE}/var ${INSTALL_DIR}/
    rm -fr ${TMP_DIR}/${PACKAGE}

    exit 0
}

