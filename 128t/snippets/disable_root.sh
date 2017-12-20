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
RESULT=`chroot $INSTALLED_ROOT su - t128 -c "whoami"`
if [ $? -eq 0 ] ; then
    chroot $INSTALLED_ROOT bash -c "usermod -s /sbin/nologin root"
    if [ $? -eq 0 ] ; then
        printf "ROOT LOGIN DISABLED...\n"
    else
        printf "FAILED to DISABLE ROOT LOGIN!!!\n"
        exit 1
    fi

    if [ -f $INSTALLER_FILES/t128_bashrc_addons ] ; then
        cat $INSTALLER_FILES/t128_bashrc_addons >> $INSTALLED_ROOT/home/t128/.bashrc
        echo "Updated t128 .bashrc"
    fi
else
    echo "User t128 Missing; root login enabled!"
fi

