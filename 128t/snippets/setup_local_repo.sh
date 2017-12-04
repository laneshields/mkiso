#########################################################################
#
# Copies local repo files from the 128T ISO and creates a local
# repository on the install target's disk.
#
# This is not a standlone bash script, it is intended to be included by 
# a kickstart file defining:
# - $INSTALLER_FILES  
# - $INSTALLED_ROOT
#
# Only include this snippet if install128t is to be run on the target
# when offline...
#
#########################################################################

YUM_CERT_DIR=$INSTALLED_ROOT/etc/pki/128technology
PACKAGE_DIR=$INSTALLED_ROOT/etc/128technology
CHROOT_REPO_DIR=/etc/128technology/Packages
REPO_FILE=$INSTALLED_ROOT/etc/yum.repos.d/install128t.repo
CHROOT_RPM_KEY_DIR=/etc/pki/rpm-gpg
RPM_KEY_DIR=$INSTALLED_ROOT$CHROOT_RPM_KEY_DIR

# process saltstack public key
mkdir -p $RPM_KEY_DIR
cp -f $INSTALLER_FILES/downloads/SALTSTACK-GPG-KEY.pub $RPM_KEY_DIR/SALTSTACK-GPG-KEY.pub
chroot $INSTALLED_ROOT bash -c "rpm --import $CHROOT_RPM_KEY_DIR/SALTSTACK-GPG-KEY.pub"

# Fool the installer into thinking it has a yum certificate
mkdir -p $YUM_CERT_DIR
touch $YUM_CERT_DIR/release.pem

# Copy ISO packages to local yum repo directory
mkdir -p $PACKAGE_DIR
echo "Start Copying Package Files..."
echo "$INSTALLER_FILES/Packages -> $PACKAGE_DIR"
rsync -avzh --progress $INSTALLER_FILES/Packages $PACKAGE_DIR
echo "Finished Copying Package Files..."

#create a local repo .repo config file
echo "Create $REPO_FILE"
echo "[install128t]" >  $REPO_FILE
echo "name=128T Standalone Repo" >> $REPO_FILE
echo "failovermethod=priority" >> $REPO_FILE
echo "sslverify=0" >> $REPO_FILE
echo "baseurl=file://$CHROOT_REPO_DIR/" >> $REPO_FILE
echo "enabled=1" >> $REPO_FILE
echo "metadata_expire=1h" >> $REPO_FILE
echo "gpgcheck=0" >> $REPO_FILE
echo "skip_if_unavailable=False" >> $REPO_FILE

echo "Create Local YUM Repository"
chroot $INSTALLED_ROOT bash -c "/usr/bin/createrepo $CHROOT_REPO_DIR"
