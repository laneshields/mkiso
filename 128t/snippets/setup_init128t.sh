#############################################################################
# 
# NOTE: This script sets up systemd to run initialize128t on the specified
#       TTY {{ISO_OVERRIDE_TTY}}. It uses:
#       -  getty_override.conf 
#       -  init128t_on_startup.sh
#
# This is not a standlone bash script, it is intended to be included by 
# a kickstart file defining:
# - $INSTALLER_FILES  
# - $INSTALLED_ROOT
#
#############################################################################

# 3.1.6: This is a temporary workaround...
# setup the python environments...
# WARNING IFS=$'\n' messes with kickstart...
PYTHON_INIT_CMDS=("128T_python_environment_init" \
                  "128T_salt_environment_init")
for cmd in ${PYTHON_INIT_CMDS[@]} ; do
    init_status="FAILED"
    echo "Starting $cmd..."
    chroot $INSTALLED_ROOT bash -c "$cmd &> /root/$cmd.log" 
    if [ $? -eq 0 ] ; then
        init_status="SUCCEEDED"
    fi
    echo "$cmd: $init_status"
done

# An assumption is made that the console device is always
# of the form 'ttyXXXX' where XXXX can change
GETTY_TYPE='getty'
OVERRIDE_TTY="{{ISO_OVERRIDE_TTY}}"
if [ -z "$OVERRIDE_TTY" ] ; then
    OVERRIDE_TTY="1"
fi
ISO_CREATE_TTY=$OVERRIDE_TTY
bootline=`cat /proc/cmdline`
if [[ $bootline =~ console=([^, ]+) ]] ; then
    consdev=${BASH_REMATCH[1]}
    if [ ! -z "$consdev" ] ; then
	consdev=${consdev/tty/}
    fi
    if [ ! -z "$consdev" ] ; then
	OVERRIDE_TTY=$consdev
    fi
fi
# for serial tty, use the 'serial-getty' service instead of 'getty'
if [ ${OVERRIDE_TTY:0:1} == "S" ] ; then
    GETTY_TYPE='serial-getty'
fi

# It should be possible to run initializer on all console=
# bootline parameter gettys, but forcing the specification of a
# console= parameter might usurp automatic console detection
# in some cases so this might have to be optional. For
# further study...
#
# override tty must be defined here
echo "Initializer ${GETTY_TYPE} device tty${OVERRIDE_TTY}"
echo "Setup initialize128t SingleStart..."

OVERRIDE_GETTY_SOURCE=$INSTALLER_FILES"/${GETTY_TYPE}_override.conf"
OVERRIDE_GETTY_DIR="/usr/lib/systemd/system/${GETTY_TYPE}@tty${OVERRIDE_TTY}.service.d"
OVERRIDE_GETTY_TARGET=$INSTALLED_ROOT"/"$OVERRIDE_GETTY_DIR"/override.conf"
INIT_ON_BOOT_NAME="init128t_on_startup.sh"
INIT_ON_BOOT_SOURCE=$INSTALLER_FILES"/"$INIT_ON_BOOT_NAME
INIT_ON_BOOT_TARGET=$INSTALLED_ROOT"/usr/bin/"$INIT_ON_BOOT_NAME

echo "Copying FirstBoot files..."

mkdir -p $INSTALLED_ROOT$OVERRIDE_GETTY_DIR
cp $OVERRIDE_GETTY_SOURCE $OVERRIDE_GETTY_TARGET
chmod 664 $OVERRIDE_GETTY_TARGET

# Adjust the script starting initialize128t to use the bootline
# console=ttyXXX device, if one was specified otherwise the
# default from ISO creation time is used. 
cp $INIT_ON_BOOT_SOURCE $INIT_ON_BOOT_TARGET
chmod 550 $INIT_ON_BOOT_TARGET
if [ $ISO_CREATE_TTY != $OVERRIDE_TTY ] ; then
    sed -i "s/^OVERRIDE_TTY=.*$/OVERRIDE_TTY=$OVERRIDE_TTY/" \
           $INIT_ON_BOOT_TARGET
fi

echo "Enable FirstBoot..."

init_status="FAILED"
chroot $INSTALLED_ROOT bash -c "systemctl enable ${GETTY_TYPE}@tty$OVERRIDE_TTY"
if [ $? -eq 0 ] ; then
    init_status="SUCCEEDED"
fi

echo "Enable $INIT_128T_FILE.service: $init_status"
