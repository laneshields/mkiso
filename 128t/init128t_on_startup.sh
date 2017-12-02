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
##########################################################################
GETTY_TYPE='getty'
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
/usr/bin/initialize128t
status=$?
if [ $status -eq 0 ] ; then
    dialog --cr-wrap --colors --title "128T Installer Status" \
           --msgbox "\n    Install SUCCEEDED \n\n Enter OK for Login Prompt" \
           8 32
else
    dialog --cr-wrap --colors --title "\Z1 128T Installer Status" \
           --msgbox "\n\n\Z1  \Zb\Zr Install Failure Code=$status \ZR\ZB\n\n Enter OK for Login Prompt" \
           9 32
fi

# clear any leftover kruft from dialog
clear

# restore original tty/console behavior
rm -f $OVERRIDE_SOURCE_DIR/override.conf
systemctl daemon-reload
# systemctl stop followed by start[serial-]getty@tty$OVERRIDE_TTY.service
# does not work, systemctl restart [serial-]getty@tty$OVERRIDE_TTY.service
# is required instead.
systemctl restart ${GETTY_TYPE}@tty${OVERRIDE_TTY}.service


