###############################################################################
#
# Setup SSH access (disable root logins via SSH)
# Disable SSH Reverse DNS lookup
#
###############################################################################
echo "Disabling SSHD Reverse DNS lookup..."
chroot $INSTALLED_ROOT sed -E -i  's/^#UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
if [ $? -eq 0 ] ; then
    echo "SSHD Reverse DNS lookup disable SUCCESS!"
else
    echo "SSHD Reverse DNS lookup disable FAILED!!!"
fi
