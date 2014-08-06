#!/bin/sh

# Package
PACKAGE="gitlab"
DNAME="Gitlab"

# Others
INSTALL_DIR="/usr/local/${PACKAGE}"
PATH="${INSTALL_DIR}/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin"
CHROOTTARGET=`realpath ${INSTALL_DIR}/var/chroottarget`


start_daemon ()
{
    # Mount if install is finished
    if [ -f ${INSTALL_DIR}/var/installed ]; then
        # Make sure we don't mount twice
        grep -q "${CHROOTTARGET}/proc " /proc/mounts || mount -t proc proc ${CHROOTTARGET}/proc
        grep -q "${CHROOTTARGET}/sys " /proc/mounts || mount -t sysfs sys ${CHROOTTARGET}/sys
        grep -q "${CHROOTTARGET}/dev " /proc/mounts || mount -o bind /dev ${CHROOTTARGET}/dev
        grep -q "${CHROOTTARGET}/dev/pts " /proc/mounts || mount -o bind /dev/pts ${CHROOTTARGET}/dev/pts
        
        # Start all services
        cp ${INSTALL_DIR}/etc/gitlab-httpd.conf /etc/httpd/sites-enabled-user/gitlab-httpd.conf
        httpd -k restart
    fi
}

stop_daemon ()
{
    # Stop running services
    rm -f /etc/httpd/sites-enabled-user/gitlab-httpd.conf
    httpd -k restart

    # Unmount
    umount ${CHROOTTARGET}/dev/pts
    umount ${CHROOTTARGET}/dev
    umount ${CHROOTTARGET}/sys
    umount ${CHROOTTARGET}/proc
}

daemon_status ()
{
    `grep -q "${CHROOTTARGET}/proc " /proc/mounts` && `grep -q "${CHROOTTARGET}/sys " /proc/mounts` && `grep -q "${CHROOTTARGET}/dev " /proc/mounts` && `grep -q "${CHROOTTARGET}/dev/pts " /proc/mounts`
}


case $1 in
    start)
        if daemon_status; then
            echo ${DNAME} is already running
            exit 0
        else
            echo Starting ${DNAME} ...
            start_daemon
            exit $?
        fi
        ;;
    stop)
        if daemon_status; then
            echo Stopping ${DNAME} ...
            stop_daemon
            exit 0
        else
            echo ${DNAME} is not running
            exit 0
        fi
        ;;
    status)
        if daemon_status; then
            echo ${DNAME} is running
            exit 0
        else
            echo ${DNAME} is not running
            exit 1
        fi
        ;;
    chroot)
        chroot ${CHROOTTARGET}/ /bin/bash
        ;;
    *)
        exit 1
        ;;
esac
