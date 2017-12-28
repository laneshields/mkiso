#!/bin/bash
##########################################################################
#
# This wrapper file controls how often initialize128t is run on startup
# and alters the tty1 getty service to resume normal logins thereafter
# (currently regardless of the success or failure). 
#
# This cannot be directly invoked as a bash script as it requires the
# template variable, {{ISO_OVERRIDE_TTY}} to be populated first
#
# WARNING!!!!!!!!!
# This file is as a mkiso.sh template.  The Bash escape character must be
# doubled -- '\\' instead of `\` for it to be effective.
#
##########################################################################
GETTY_TYPE='getty'
LOCAL_REPO_DIR=/etc/128technology/Packages
YUM_CERT_FILE=/etc/pki/128technology/release.pem
OVERRIDE_TTY="{{ISO_OVERRIDE_TTY}}"
if [ -z "$OVERRIDE_TTY" ] ; then
    OVERRIDE_TTY="1"
fi
# if the tty device is /dev/ttySN (SN since the tty prefix is not passed)
# use the serial systemd servies template
if [ ${OVERRIDE_TTY:0:1} == "S" ] ; then
    GETTY_TYPE='serial-getty'
fi
# This directory may benefit from being an mkiso.sh template variable,
# similar to ISO_OVERRIDE_TTY...
OVERRIDE_SOURCE_DIR="/usr/lib/systemd/system/${GETTY_TYPE}@tty${OVERRIDE_TTY}.service.d"
if [ -d ${LOCAL_REPO_DIR} ] ; then
    # yum-config-manager --save --setopt=\*.skip_if_unavailable=True &> /dev/null
    /usr/bin/install128t -a
else    
    /usr/bin/initialize128t
fi
status=$?

# Run the table creator when kickstart/anaconda do the 128T install
# as the Cassandra JVM cannot be started during the post-install scripts
if [ ! -d ${LOCAL_REPO_DIR} -a $status -eq 0 ] ; then
    /usr/bin/t128TableCreator -v 2>&1 | \\
	dialog --cr-wrap --colors --title "128T Statistics Table Creator" \\
        --programbox 16 40
    status=$?
fi

start_sw=1
if [ $status -eq 0 ] ; then
    dialog --no-collapse --cr-wrap --colors --title "128T Installer Status" --yesno \\
           "\\n      \\Zb\\Z2Install SUCCESS\\Z0\\ZB\\n\\n    Start 128T Router\\n    before proceeding to\\n    login prompt?" \\
           10 32
    start_sw=$?
else
    dialog --cr-wrap --no-collapse --colors --title "\\Z1 128T Installer Status" \\
           --msgbox "\\n\\n\\Z1  \\Zb\\Zr Install Failure Code=$status \\ZR\\ZB\\n\\n Enter OK for Login Prompt" \\
           9 32
fi

# Enable retries for all repos if install128t was used
if [ -d ${LOCAL_REPO_DIR} ] ; then
    #yum-config-manager --save --setopt=\*.skip_if_unavailable=False
    rm -f $YUM_CERT_FILE
fi

# clear any leftover kruft from dialog
clear

# start 128T if so desired...
if [ $start_sw -eq 0 ] ; then
    systemctl enable 128T &> /dev/null
    systemctl start 128T &> /dev/null
fi

# restore original tty/console behavior
rm -f ${OVERRIDE_SOURCE_DIR}/override.conf
systemctl daemon-reload
# systemctl stop followed by start[serial-]getty@tty$OVERRIDE_TTY.service
# does not work, systemctl restart [serial-]getty@tty$OVERRIDE_TTY.service
# is required instead.
systemctl restart ${GETTY_TYPE}@tty${OVERRIDE_TTY}.service


