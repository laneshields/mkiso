##############################################################################
##############################################################################
##
## Disable root logins:
## --------------------
##
## This script is intended to be run from a kickstart file defining 
## the following variables:
##
## INSTALLER_FILES=/mnt/install/repo
## INSTALLED_ROOT=/mnt/sysimage
##
###############################################################################
###############################################################################
echo chroot $INSTALLED_ROOT bash -c "sed -i 's|^root\\(.*\\)\\(/bin/bash\\)|root\1/sbin/nologin|' /etc/passwd"
chroot $INSTALLED_ROOT bash -c "sed -i 's|^root\\(.*\\)\\(/bin/bash\\)|root\\1/sbin/nologin|' /etc/passwd"
chroot $INSTALLED_ROOT cp -f /etc/passwd /root/passwd_data.txt
if [ $? -eq 0 ] ; then
    printf "ROOT LOGIN DISABLED...\n"
else
    printf "FAILED to DISABLE ROOT LOGIN!!!\n"
fi

