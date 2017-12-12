###############################################################################
#
# Configure firewalld for 128T interfaces
#
# Use firewall-offline-cmd in chroot, as firewall-cmd  requires that firewalld
# be running, and this is not allowed in the chroot environment used by 
# anaconda kickstart
#
# This is an ugly hack until the PCLI / GUI gets control of the management 
# interface configuration.  All interfaces are allowed http,https,zookeeper, 
# and salt-master access as we don't know yet what the management interface
# will be.  Not so safe, but safer than firewalld being disabled...
#
# This is a snippet intended to be included in a kickstart file
# - Uses $INSTALLER_FILES
# - Uses $INSTALLER_ROOT
#
###############################################################################
FWCMD='firewall-offline-cmd'
FIREWALLD_SERVICE_PATH=$INSTALLED_ROOT/etc/firewalld/services

echo "Configuring firewalld..."

cp -f $INSTALLER_FILES/zookeeper.xml $FIREWALLD_SERVICE_PATH
cp -f $INSTALLER_FILES/salt-master.xml $FIREWALLD_SERVICE_PATH

# enable firewalld service (no need to start; will happen on reboot)
chroot $INSTALLED_ROOT bash -c "systemctl enable firewalld"

#create interface-agnostic t128 virtual zone
chroot $INSTALLED_ROOT bash -c "$FWCMD --new-zone=t128"

#allow https connectivity for zone t128
chroot $INSTALLED_ROOT bash -c "$FWCMD --zone=t128 --add-service=https"

#allow ssh connectivity for zone t128
chroot $INSTALLED_ROOT bash -c "$FWCMD --zone=t128 --add-service=ssh"

#allow ssh connectivity for zone t128
chroot $INSTALLED_ROOT bash -c "$FWCMD --zone=t128 --add-service=zookeeper"

#allow ssh connectivity for zone t128
chroot $INSTALLED_ROOT bash -c "$FWCMD --zone=t128 --add-service=salt-master"

#Drop any traffic that doesn't match expected sources / services
chroot $INSTALLED_ROOT bash -c "$FWCMD --zone=t128 --set-target=DROP"

# set default zone to t128
chroot $INSTALLED_ROOT bash -c "$FWCMD --set-default-zone=t128"

echo "Firewalld configuration completed..."

