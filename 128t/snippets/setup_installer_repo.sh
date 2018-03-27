#########################################################################
#
# Installs the repo.rpm package which must be available in
# $CHROOT_REPO_DIR/repo.rpm
#
# This is not a standlone bash script, it is intended to be included by 
# a kickstart file defining:
# - $INSTALLER_FILES  
# - $INSTALLED_ROOT
#
#########################################################################
CHROOT_REPO_DIR=$INSTALLED_ROOT/tmp

# process saltstack public key
echo "Install 128T package: repo.rpm"
cp -f $INSTALLER_FILES/downloads/repo.rpm $CHROOT_REPO_DIR/repo.rpm
chroot $INSTALLED_ROOT bash -c "yum -y install /tmp/repo.rpm"
if [ $? -ne 0 ] ; then
    printf "Failed to install repo.rpm to target disk!"
    exit 1
fi
