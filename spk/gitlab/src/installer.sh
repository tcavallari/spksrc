#!/bin/sh

# Package
PACKAGE="gitlab"
DNAME="Gitlab"

# Others
INSTALL_DIR="/usr/local/${PACKAGE}"
CHROOTTARGET="${INSTALL_DIR}/var/chroottarget"
PATH="${INSTALL_DIR}/bin:${INSTALL_DIR}/env/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin"
CHROOT_PATH="/usr/local/bin:/usr/bin:/bin"
TMP_DIR="${SYNOPKG_PKGDEST}/../../@tmp"

preinst ()
{
    exit 0
}

postinst ()
{
    # Link
    ln -s ${SYNOPKG_PKGDEST} ${INSTALL_DIR}

    # Debootstrap second stage in the background and configure the chroot environment
    if [ "${SYNOPKG_PKG_STATUS}" != "UPGRADE" ]; then
        # Make sure we don't mount twice
        mount | grep -q "${CHROOTTARGET}/proc " || mount -t proc proc ${CHROOTTARGET}/proc
        mount | grep -q "${CHROOTTARGET}/sys " || mount -t sysfs sys ${CHROOTTARGET}/sys
        mount | grep -q "${CHROOTTARGET}/dev " || mount -o bind /dev ${CHROOTTARGET}/dev
        mount | grep -q "${CHROOTTARGET}/dev/pts " || mount -o bind /dev/pts ${CHROOTTARGET}/dev/pts

        ( 
            chroot ${CHROOTTARGET}/ /debootstrap/debootstrap --second-stage && \
            mv ${CHROOTTARGET}/etc/apt/sources.list.default ${CHROOTTARGET}/etc/apt/sources.list && \
            mv ${CHROOTTARGET}/etc/apt/preferences.default ${CHROOTTARGET}/etc/apt/preferences && \
            cp /etc/hosts /etc/hostname /etc/resolv.conf ${CHROOTTARGET}/etc/ && \
            chroot ${CHROOTTARGET}/ /bin/bash /bootstrap.sh && \
            echo "All done!" && \
            touch ${INSTALL_DIR}/var/installed
        ) | cat > ${INSTALL_DIR}/var/install.log 2&>1

        chmod 666 ${CHROOTTARGET}/dev/null
        chmod 666 ${CHROOTTARGET}/dev/tty
        chmod 777 ${CHROOTTARGET}/tmp

        # Unmount
        umount ${CHROOTTARGET}/dev/pts
        umount ${CHROOTTARGET}/dev
        umount ${CHROOTTARGET}/sys
        umount ${CHROOTTARGET}/proc
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

