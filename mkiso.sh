#!/bin/bash
############################################################################
#
#              _    _                _
#     _ __ ___ | | _(_)___  ___   ___| |__
#    | '_ ` _ \| |/ / / __|/ _ \ / __| '_ \
#    | | | | | |   <| \__ \ (_) |\__ \ | | |
#    |_| |_| |_|_|\_\_|___/\___(_)___/_| |_|
#
#     Version 1.0
#
#     Copyright (C) 128 Technology (2017). All Rights Reserved.
#
#     This script builds customized ISOs from stock Linux distributions
#     (e.g. CentOS). For detailed configuration refer to README.txt
#
#     Basic Usage:
#     mkiso.sh create --config=<config-file> --iso-in=/path/to.iso
#
#     Non absolute pathnames are defaulted.
#
############################################################################

#
# Set extended regular expressions.  Required in bash for examples like PCRE
# [:space:]*, which is expressed in bash glob as *([[:space:]])
#
shopt -s extglob
#set -u
#set -x

# Turns on additional output, useful for debugging
# 0=on, 1=off (typical bash)
DEBUG_FLAG=1

# Global status values
STATUS_OK=0
STATUS_FAIL=1

PKGBIN=/usr/bin/yum

#
# Prefix to yum repository entries in a generated
# yum.conf (used to present a different set of repos to yum
# than those used by default (/etc/yum.conf) to
# install/update the development VM.
#
YUM_CONF_FILE_SEED="[main]
cachedir=/var/cache/yum/\$basearch/\$releasever
keepcache=0
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
installonly_limit=5
bugtracker_url=http://bugs.centos.org/set_project.php?project_id=23&ref=\
http://bugs.centos.org/bug_report_page.php?category=yum
distroverpkg=centos-release
"

# kmod-hfsplus requires this repo...
YUM_ELREPO_CONFIG_FILE='/etc/yum.repos.d/elrepo.repo'
YUM_ELREPO_GPG_KEY='https://www.elrepo.org/RPM-GPG-KEY-elrepo.org'
YUM_128T_INSTALL_REPO_CONFIG_FILE='/etc/yum.repos.d/installer.repo'

#
# Additional RPMS which must be installed in order to
# create ISOs...
#
# <rpm-pattern-to-test>[,<rpm-pattern-to-download>]
#
REQUIRED_RPMS="
  genisoimage \
  hfsplus-tools \
  kmod-hfsplus,kmod-hfsplus-0.0-3 \
  cifs-utils \
  isomd5sum \
  createrepo \
  syslinux \
  curl
"

# terminal color/style control characters
TERMINAL_COLOR_RED='\033[0;31m'
TERMINAL_COLOR_BLUE='\033[0;34m'
TERMINAL_COLOR_GREEN='\033[0;32m'
TERMINAL_COLOR_NONE='\033[0m'
TERMINAL_STYLE_BOLD=$(tput bold)
TERMINAL_STYLE_NORMAL=$(tput sgr0)

MKISO_ID_COOKIE='jr5kbeptmjce84js;2w'
MKISO_WORKSPACE_ID=".mkiso_workspace_dir_$MKISO_ID_COOKIE"

#
# command-specific usage banners
# '_' is replaced with ' ' at time of printing
# to help with proper indentation...
#
# The second empty line in each help array delimits between summary
# (displayed when mkiso.sh is issued w/o a command) and full help text
# (dislayed when mkiso.sh is issued with too few or invalid parameters).
#
MKISO_HELP_EMPTY_LINE_COUNT=2

declare -a aShowHelp
aShowHelp[0]='mkiso.sh show --config=<config-file> ...'
aShowHelp[1]=''
aShowHelp[2]='_________Display mkiso.sh parameters.  Additional parameters may be provided'
aShowHelp[3]='_________on the command line to override those provided in configuration file'
# The empty line below delimits the summary displayed when no command is specified to mkiso.sh
aShowHelp[4]=''
aShowHelp[5]='--config: Path to configuration file. If an absolute path is not specified'
aShowHelp[6]='__________The directory from which mkiso.sh is started is prepended. Strictly'
aShowHelp[7]='__________speaking if no --config value is provided a default of `pwd`/mkiso.cfg'
aShowHelp[8]='__________is tried, but currently no default mkiso.cfg is provided.'
aShowHelp[9]=''
aShowHelp[10]='See README.txt for more detail'

declare -a aCreateHelp
aCreateHelp[0]='mkiso.sh create --config=<config-file> [--iso-in=</path/to/input-iso>] ...'
aCreateHelp[1]=''
aCreateHelp[2]='_________Create a customized bootable ISO from an input distribution ISO plus'
aCreateHelp[3]='_________mkiso.sh configuration and supporting files'
# The empty line below delimits the summary displayed when no command is specified to mkiso.sh
aCreateHelp[4]=''
aCreateHelp[5]='--config:  Path to configuration file. If an absolute path is not specified'
aCreateHelp[6]='__________The directory from which mkiso.sh is started is prepended. Strictly'
aCreateHelp[7]='__________speaking if no --config value is provided a default of `pwd`/mkiso.cfg'
aCreateHelp[8]='__________is tried, but currently no default mkiso.cfg is provided.'
aCreateHelp[9]=''
aCreateHelp[10]='--iso-in:  Path to distribution ISO from which to create the new iso.'
aCreateHelp[11]='__________This will default to using samba access to file.128technologys.com'
aCreateHelp[12]='__________If a non-absolute path is used, the users $HOME directory is'
aCreateHelp[13]=''
aCreateHelp[14]='See README.txt for more detail'

declare -a aTestHelp
aTestHelp[0]='mkiso.sh test --config=<config-file> --iso-in=</path/to/input-iso> ...'
aTestHelp[1]=''
aTestHelp[2]='_________Install a customized bootable ISO created by mkiso.sh (or which has a'
aTestHelp[3]='_________kickstart file stored at the top level directory)'
# The empty line below delimits the summary displayed when no command is specified to mkiso.sh
aTestHelp[4]=''
aTestHelp[5]='--config: Path to configuration file. This is used primarily to provide overrides'
aTestHelp[6]='__________to mkiso.sh parameters as an ISO is not actually being genereated'
aTestHelp[9]=''
aTestHelp[10]='--iso-in:  Path to mkiso.sh to test a yum install of.'
aTestHelp[11]=''
aTestHelp[12]='See README.txt for more detail'

declare -a aRpm2IsoHelp
aRpm2IsoHelp[0]='mkiso.sh rpm2iso --config=<config-file> --rpm-file==</path/to/rpm-list>'
aRpm2IsoHelp[1]='_________________--iso-in=</path/to/input-iso> ...'
aRpm2IsoHelp[2]=''
aRpm2IsoHelp[3]='_________Create a customized bootable ISO from a distribution ISO plus'
aRpm2IsoHelp[4]='_________a list of specific RPMs and mkiso.sh configuration plus'
aRpm2IsoHelp[5]='_________supporting files.'
# The empty line below delimits the summary displayed when no command is specified to mkiso.sh
aRpm2IsoHelp[6]=''
aRpm2IsoHelp[7]='--config:___Path to configuration file. If an absolute path is not specified'
aRpm2IsoHelp[8]='____________The directory from which mkiso.sh is started is prepended. Strictly'
aRpm2IsoHelp[9]='____________speaking if no --config value is provided a default of `pwd`/mkiso.cfg'
aRpm2IsoHelp[10]='____________is tried, but currently no default mkiso.cfg is provided.'
aRpm2IsoHelp[11]=''
aRpm2IsoHelp[12]='--rpm-file: Path to a list of RPMS as generated by rpm -qa (note these entries'
aRpm2IsoHelp[13]='____________do not have a .rpm suffix'
aRpm2IsoHelp[14]=''
aRpm2IsoHelp[15]='--iso-in:___Path to distribution ISO from which to create the new iso.'
aRpm2IsoHelp[16]='____________This will default to using samba access to file.128technologys.com'
aRpm2IsoHelp[17]='____________If a non-absolute path is used, the users $HOME directory is'
aRpm2IsoHelp[18]=''
aRpm2IsoHelp[19]='See README.txt for more detail'

declare -a aRepoHelp
aRepoHelp[0]='mkiso.sh repo --config=<config-file>'
aRepoHelp[2]=''
aRepoHelp[3]='_________Create only the repository directory with packages and repodata'
# The empty line below delimits the summary displayed when no command is specified to mkiso.sh
aRepoHelp[4]=''
aRepoHelp[5]='--config:___Path to configuration file. If an absolute path is not specified'
aRepoHelp[6]='____________The directory from which mkiso.sh is started is prepended. Strictly'
aRepoHelp[7]='____________speaking if no --config value is provided a default of `pwd`/mkiso.cfg'
aRepoHelp[8]='____________is tried, but currently no default mkiso.cfg is provided.'
aRepoHelp[9]=''
aRepoHelp[10]='See README.txt for more detail'

#
# Ass. Array of functions basen on URL protocol
#
declare -A URL_HELPER_FUNCS
URL_HELPER_FUNCS['http']=get_http_iso
URL_HELPER_FUNCS['smb']=query_samba_iso

#
# create_elrepo:
#
# Creates the ELREPO Yum repository confguration file, required
# for kmod-hfsplus (used as part of ISO creation)
#
function create_elrepo {
sudo bash -c "cat > $YUM_ELREPO_CONFIG_FILE << 'EOF'
### Name: ELRepo.org Community Enterprise Linux Repository for el7
### URL: http://elrepo.org/

[elrepo]
name=ELRepo.org Community Enterprise Linux Repository - el7
baseurl=http://elrepo.org/linux/elrepo/el7/\$basearch/
http://mirrors.coreix.net/elrepo/elrepo/el7/\$basearch/
http://jur-linux.org/download/elrepo/elrepo/el7/\$basearch/
http://repos.lax-noc.com/elrepo/elrepo/el7/\$basearch/
http://mirror.ventraip.net.au/elrepo/elrepo/el7/\$basearch/
mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo.el7
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0

[elrepo-testing]
name=ELRepo.org Community Enterprise Linux Testing Repository - el7
baseurl=http://elrepo.org/linux/testing/el7/\$basearch/
http://mirrors.coreix.net/elrepo/testing/el7/\$basearch/
http://jur-linux.org/download/elrepo/testing/el7/\$basearch/
http://repos.lax-noc.com/elrepo/testing/el7/\$basearch/
http://mirror.ventraip.net.au/elrepo/testing/el7/\$basearch/
mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo-testing.el7
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0

[elrepo-kernel]
name=ELRepo.org Community Enterprise Linux Kernel Repository - el7
baseurl=http://elrepo.org/linux/kernel/el7/\$basearch/
http://mirrors.coreix.net/elrepo/kernel/el7/\$basearch/
http://jur-linux.org/download/elrepo/kernel/el7/\$basearch/
http://repos.lax-noc.com/elrepo/kernel/el7/\$basearch/
http://mirror.ventraip.net.au/elrepo/kernel/el7/\$basearch/
mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo-kernel.el7
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0

[elrepo-extras]
name=ELRepo.org Community Enterprise Linux Extras Repository - el7
baseurl=http://elrepo.org/linux/extras/el7/\$basearch/
http://mirrors.coreix.net/elrepo/extras/el7/\$basearch/
http://jur-linux.org/download/elrepo/extras/el7/\$basearch/
http://repos.lax-noc.com/elrepo/extras/el7/\$basearch/
http://mirror.ventraip.net.au/elrepo/extras/el7/\$basearch/
mirrorlist=http://mirrors.elrepo.org/mirrors-elrepo-extras.el7
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-elrepo.org
protect=0
EOF"
return $?
}

function create_128t_install_repo {
sudo bash -c "cat > $YUM_128T_INSTALL_REPO_CONFIG_FILE << EOF
###
### 128T Installer repository.  Used to start the 128T
### installation process.
###
[128t-installer]
name=128 Technology Installer
failovermethod=priority
sslverify=0
baseurl=https://west.yum.128technology.com/installer/repo/Release
enabled=1
metadata_expire=3600
gpgcheck=0
skip_if_unavailable=0
keepcache = 0
EOF"
return $?
}

#
# cleanup_mounts
#
# $1 - IN: name of parameters array
#
function cleanup_mounts {
    local _func=${FUNCNAME}
    local _key
    local _rv
    local _astr
    local _avals
    local _aname=$1

    local _keys=(iso_mount_path efi_mount_path samba_mount_path)

    if [ -z "$_aname" ] ; then
        printf "%s: No parameter array name provided\n" $_func
        return 1
    fi

    _astr=$(declare -p $_aname)
    eval "readonly -A _avals="${_astr#*=}

    # perform unmounting...
    for _key in "${_keys[@]}" ; do
        if [ ! -z "${_avals[$_key]}" ] ; then
            # Sometimes it seems rsync gets stuck after CTL-C, and
            # may need to be killed off in order to free up the mount
            # point so it can be unmounted...
            printf "Attempt unmount of %s\n" "${_avals[$_key]}"
            if [ "$_key" == 'samba_mount_path' ] ; then
                # CIFS must be treated differently...
                sudo umount -i -f -t cifs "${_avals[$_key]}" -l
                _rv=$?
            else
                sudo umount "${_avals[$_key]}"
                _rv=$?
            fi
            if [ $_rv -eq 0 ] ; then
                printf "...unmount SUCCESS!\n"
            fi
        fi
    done
}

#
# Trap CTL-C:
# Cleanup any mounts which might be left hanging...
#
trap '{
    output_n_chars '*' 75
    printf "* CTL-C Interrupt \n"
    printf "* Cleanup Mounts\n"
    output_n_chars '*' 75

    cleanup_mounts MKISO_VALS

    exit 1
}' INT

#
# aname_to_string:
#
function aname_to_string {
   local _str
   local _str2=$2
   if [ -x "$1" -o -z "$2" ] ; then
       return 1
   fi
   _str=$(declare -p $1)
   _str=${_str#*=}
   eval "$_str2="$_str
   return 0
}

#
# _error
#
function show_error {
    local _fmt=$1
    local _prestr=${TERMINAL_COLOR_RED}
    local _prestr=${_prestr}${TERMINAL_STYLE_BOLD}
    local _poststr=${TERMINAL_STYLE_NORMAL}
    local _str=''
    local _pstr=''
    local _strunc=''
    local _maxlen=78
    local _lc=0
    local _spacendx=0

    _fmt=$1
    if [ -z "$_fmt" ] ; then
        return 1
    fi
    shift

    _str=$(printf "$_fmt" "$@")
    _strunc=${_str#*:}
    _colndx=$((${#_str} - ${#_strunc} + 1))
    while [ $_colndx -gt 0 ] ; do
       _indent="$_indent "
       _colndx=$((_colndx-1))
    done
    printf "\n"
    printf "${_prestr}+-------------------------------------------------------------------------------\n${_poststr}"
    while [ "$_str" != '' ] ; do
        if [ $_lc -gt 0 ] ; then
            _str="$_indent$_str"
        fi
        if [ ${#_str} -lt $_maxlen ] ; then
            _pstr="$_str"
            _str=''
        else
            _pstr="${_str:0:$_maxlen}"
            _strunc=${_pstr##* }
            _spacendx=$((${#_pstr} - ${#_strunc}))
            if [ $_spacendx -eq 0 ] ; then
                _spacendx=$_maxlen
            fi
            _pstr="${_str:0:$_spacendx}"
            _str="${_str:$_spacendx}"
        fi
        printf "${_prestr}| %s${_poststr}\n" "${_pstr}"
        _lc=$((_lc + 1))
        if [ $_lc -gt 10 ] ; then
            break
        fi
    done
    printf "${_prestr}+-------------------------------------------------------------------------------\n\n${_poststr}"
}

#
# check_bash_version:
#
# $1  IN: The minimum acceptable version
#
function check_bash_version {
    local _sver=$1
    local _verArrayIn
    local _verLine
    local _bashVer
    local _verArrayBash
    local _verArrayInLen
    local _verArrayBashLen
    local _verLen
    local i=0
    local _v1
    local _v2

    if [ -z "_sver" -o "_sver" == "" ] ; then
        printf "check_bash_version: Cannot get version!!!\n"
        return 1
    fi

    _verArrayIn=(${_sver//\./ })
    _verLine=`bash --version | head -n 1`
    if [[ $_verLine =~ ([0-9\.-]+) ]] ; then
        _bashVer=${BASH_REMATCH[1]}
    fi
    if [ -z "$_bashVer" -o "$_bashVer" == "" ] ; then
        printf "Unable to extract bash version!!!!"
        return 1
    fi
    _verArrayBash=(${_bashVer//\./ })
    _verArrayInLen=${#_verArrayIn[@]}
    _verArrayBashLen=${#_verArrayBash[@]}
    _verLen=$_verArrayInLen
    if [ $_verLen -gt $_verArrayBashLen ] ; then
        _verLen=$_verArrayBashLen
    fi
    while [ $i -lt $_verLen ] ; do
        _v1=${_verArrayIn[${i}]}
        _v2=${_verArrayBash[${i}]}
        if [ $_v1 -gt $_v2 ] ; then
            printf "BASH %s < Required %s\n" $_bashVer $_sver
            return 1
        fi
        i=$((i + 1))
    done
    printf "BASH %s >= Required %s\n" $_bashVer $_sver
    return 0
 }

#
# check_installed_rpms:
#
# check installed rpms to see if required tools are installed...
#
# $1 - "on" (or not provided) to prompt before each install, otherwise off
#
function check_installed_rpms {
    local _func=${FUNCNAME}
    local _rpm
    local _rpmEntry
    local _rpmData
    local _getrpm
    local _val
    local _status
    local _doit

    # Check for the elrepo repository...
    printf "%s: Check REPO EL...\n" $_func
    yum repolist | grep elrepo &> /dev/null
    if [[ $? -ne 0 && ! -f $YUM_ELREPO_CONFIG_FILE ]] ; then
        if [[ -z "$1" || ${1^^} == "ON" ]] ; then
            echo "-----------------------------------------------"
            echo -n "Install Yum ELREPO Configuration [n/y]: "
            read _doit
        else
            _doit="y"
        fi
        if [ ! -z "$_doit" -a "$_doit"=="y" ] ; then
             create_elrepo
             if [ $? -ne 0 ] ; then
                  printf "%s:Install $YUM_ELREPO_CONFIG_FILE FAILED\n" $_func
                  return 1
             fi
             sudo rpm --import $YUM_ELREPO_GPG_KEY
             if [ $? -ne 0 ] ; then
                  printf "%s: Install $YUM_ELREPO_GPG_KEY FAILED\n" $_func
                  return 1
             fi
        fi
    fi

    # Check for the elrepo repository...
    printf "%s: Check REPO EPEL...\n" $_func
    yum repolist | grep epel &> /dev/null
    if [ $? -ne 0 ] ; then
        if [[ -z "$1" || ${1^^} == "ON" ]] ; then
            echo "-----------------------------------------------"
            echo -n "Install Yum EPEL Configuration [n/y]: "
            read _doit
        else
            _doit="y"
        fi
        if [ ! -z "$_doit" -a "$_doit"=="y" ] ; then
             sudo yum -y install epel-release
             if [ $? -ne 0 ] ; then
                  printf "%s: Install EPEL Repository FAILED\n" $_func
                  return 1
             fi
        fi
    fi

    # Check for the 128T installer repository...
    printf "%s: Check REPO 128t-installer...\n" $_func
    yum repolist | grep 128t-installer  &> /dev/null
    if [ $? -ne 0 -a ! -f $YUM_128T_INSTALL_REPO_CONFIG_FILE ] ; then
        echo "-----------------------------------------------"
        echo -n "Install Yum 128TInstall Configuration [n/y]: "
        read _doit
        if [ ! -z "$_doit" -a "$_doit"=="y" ] ; then
             create_128t_install_repo
             if [ $? -ne 0 ] ; then
                  printf "%s:Install $YUM_128T_INSTALL_REPO_CONFIG_FILE FAILED\n" $_func
                  return 1
             fi
        fi
    fi

    for _rpmEntry in $REQUIRED_RPMS; do
        _rpmData=(${_rpmEntry//,/ })
        _rpm=${_rpmData[0]}
        if [ -z "${_rpmData[1]}" ] ; then
            _getrpm=$_rpm
        fi
        printf "%s: Check RPM %s...\n" $_func $_rpm
        _val=`rpm -qa "$_rpm*"`
        if [ -z "$_val" ] ; then
            if [[ -z "$1" || ${1^^} == "ON" ]] ; then
                echo "-----------------------------------------------"
                echo -n "Install $_rpm [n/y]: "
                read _doit
            else
                _doit="y"
            fi
            if [ ! -z "$_doit" -a "$_doit"=="y" ] ; then
                sudo yum -y install $_rpm
                if [ $? -ne 0 ] ; then
                    printf "%s: install %s FAILED\n" $_func $_getrpm
                    return 1
                fi
            fi
        fi
    done

    return 0
}

#
# dump_assoc:
# dumps array content
#
# $1 - IN: Array NAME
#
# Note that the following results in array[0]='string'
#     declare -A array='([a]="b" [c]="d" [e]="f")
#     array='string'
#
#     This means that the following sequence will not be correct;
#     declare -A array
#     do_something array
#        _array_name=$1
#        _str=$(declare -p $_array_name)
#        eval "declare -A _myarray="${_str#*=}
#        _str=$(declare -A array)
#        eval $_array_name=${_str#*=} <--- BAD
#        return
#     eval "declare -A array="${array} <- might be BAD
#
function dump_assoc {
   local _func=${FUNCNAME}

   if [ -z "$1" ] ; then
       printf "%s: ERROR No Array Provided\n" $_func
       return 1
   fi

   local _as
   local _a
   local key
   local skey
   local keys

   _as=$(declare -p $1)
   eval "readonly -A _a="${_as#*=}

   # sort the output list...
   keys=`echo "${!_a[@]}" | tr ' ' '\n' | sort`
   for key in $keys ; do
       skey="params[${key}]"
       indent=30
       printf "%-${indent}s : %s\n" $skey "${_a[$key]}"
   done

   return 0
}

#
# Mounts a samba filesystem...
#
# unmounting is the same as for any fstype...
#
function mount_samba_fs {
    local _func=${FUNCNAME}
    local _resource=$1
    local _mount_path=$2
    local _user=$3

    if [ -z "$_resource" ] ; then
        printf "%s: resource not provided:\n" $_func
        return 1
    fi
    if [ -z "$_mount_path" ] ; then
        printf "%s: mount path not provided\n" $_func
        return 1
    fi
    if [ -z "$_user" ] ; then
        printf "%s: username not provided\n" $_func
        return 1
    fi

    printf "%s: sudo mount -r -t cifs %s %s -o username=%s\n" \
        ${FUNCNAME[0]} $_resource $_mount_path $_user
    sudo mount -r -t cifs $_resource $_mount_path -o username=$_user
    if [ $? -ne 0 ] ; then
        printf "%s: Failed to mount Samba //%s/%s\n" $_func $_host $_resource
        return
    fi

    return 0
}

#
# query_samba_iso:
#
# $1 - IN:  input argument array
# $2 - OUT: updated array string
#
function query_samba_iso {
    local _aname=$1
    local _sout=$2
    local _astr
    local _args

    _astr=$(declare -p $_aname)
    eval "declare -A _args="${_astr#*=}

    echo "---------------------------------------------------------"
    echo "No input ISO filename specified."
    echo "A default CentOS ISO from 'files.128technology.com' is available."
    echo "Using SAMBA.  You will need to provide your LDAP password."
    echo ""
    echo -n "Would you like to use the default ISO [y/n]: "
    read _reply
    if [ -z "$ _reply" -o "$_reply" != 'y' ] ; then
        return 1
    fi

    # this will query for a password...
    mount_samba_fs ${_args[samba_resource]} ${_args[samba_mount_path]} ${_args[samba_user]}
    if [ $? -ne 0 ] ; then
        return 1
    fi

    echo ""

    # Override the ISO input file to be the samba mount...
    # TODO: it may be necessary to copy locally before it can be loop mounted...
    _args[iso-in]="${_args[samba_mount_path]}/${_args[samba_iso_file]}"

    _astr=$(declare -p _args)
    eval "$_sout="${_astr#*=}

    return 0
}

#
# get_http_iso:
#
# $1 - IN:  input argument array
# $2 - OUT: updated array string
#
function get_http_iso() {
    local _aname=$1
    local _sout=$2
    local _origdir=`pwd`
    local _astr
    local _args
    local _isofn
    local _wget_path
    local _wget_dir='wget-iso'
    local _func=${FUNCNAME[0]}

    _astr=$(declare -p $_aname)
    eval "declare -A _args="${_astr#*=}

    _isofn=`basename ${_args[iso-in]}`
    if [ -z "${_isofn}" ] ; then
         print_error "$_func: iso filename not provided!"
         return $STATUS_FAIL
    fi

    if [ "${_isofn: -4}" != ".iso" ] ; then
         print_error "$_func: $_isofn missing .iso extension"
         return $STATUS_FAIL
    fi

    _wget_path=${_args[workspace]}/${_wget_dir}
    mkdir -p ${_wget_path}

    cd ${_wget_path}
    printf "$_func: wget -N ${args[iso-in]} -> ${_wget_path}\n"
    wget -N ${_args[iso-in]}
    _status=$?
    cd $_origdir

    if [ $_status -ne 0 ] ; then
        printf "$_func: wget -N ${args[iso-in]} FAILED($_status)\n"
        return $_status
    fi

    # Overwrite the iso-in path...
    _args[iso-in]="${_wget_path}/${_isofn}"

    _astr=$(declare -p _args)
    eval "$_sout="${_astr#*=}

    return $STATUS_SUCESS
}

#
# process_iso_url:
#
function process_iso_url {
    local _pname=$1
    local _pstrout=$2
    local _proto=''
    local _status=''
    local _func=${FUNCNAME[0]}

    if [ -z "$_pname" ] ; then
        print_error "$_func: No parameter array passed!"
        return $STATUS_FAIL
    fi
    if [ -z "$_pstrout" ] ; then
        print_error "$_func: No output string passed!"
        return $STATUS_FAIL
    fi

    _pstr=$(declare -p $_pname)
    eval "declare -A _params="${_pstr#*=}
    _proto=''

    printf "%s: Process URL=%s\n" $_func ${_params[iso-in]}

    # Use smb: by default...
    if [ -z "${_params[iso-in]}" ] ; then
        _params[iso-in]="smb:${params[samba_resource]}"
    fi

    if [[ ${_params[iso-in]}  =~ ^([A-Za-z]+): ]] ; then
        _proto=${BASH_REMATCH[1]}
    fi

    # Do something only if a protocol is extracted
    if [ "$_proto" != "" ]  ; then
        if [ ! -z ${URL_HELPER_FUNCS[$_proto]} ] ; then
            printf "%s: eval %s _params _pstr\n" $_func ${URL_HELPER_FUNCS[$_proto]}
            eval "${URL_HELPER_FUNCS[$_proto]} _params _pstr"
            _status=$?
            if [ $_status -ne 0 ] ; then
                print_error "$_func: Error $_status executing ${URL_HELPER_FUNCS[$_proto]}"
                return $STATUS_FAIL
            fi
            # put the array back together...
            eval "declare -A _params="$_pstr
        else
            print_error "$_func: Unsupported URL proto $_proto"
        fi
    else
        printf "$_func: No protocol to apply\n"
    fi

    _pstr=$(declare -p _params)
    eval "$_pstrout="${_pstr#*=}

    return $STATUS_OK
}

#
# process_args:
#
# $1  - Mode (either cmdline or file)
# $2  - Name of argument definitions associative array
# $3  - Name of argument values associative array string...
# $4+ - Command Line arguments to parse
#
# Arguments form the comamnd line are expected to be in the format:
# --argument=<value> -> one value
# --argument={<value-1> <value-2> .... <value-n>} -> multiple values (or a string with spaces)
# --argument -> no value; a boolean flag
#
# Some arguments can be present multiple times
# Some arguments do not allow {}s in the value
#
# Each line form a file is prefixed with [<line-number>]--<arg-name>
#
# process_args:
#
function process_args {
    local _label=${FUNCNAME}
    local _func=$_label
    local _mode=$1
    local _astr=''

    tprint "$DEBUG_FLAG" "%s: \n" $_func "$*"

    # mode
    if [ -z "$_mode" ] ; then
        printf "%s: No mode argument\n" $_func
        return 1
    fi
    if [ "$_mode" != "cmdline" -a "$_mode" != "file" ] ; then
        printf "%s: Invalid mode=\n" $_func "$_mode"
        return 1
    fi
    shift

    # grab the definitions array name...
    local _argDefsArray=$1
    if [ -z "$_argDefsArray" -o "${_argDefsArray:0:2}" == '--' ] ; then
        printf "%s: Definitions array not provided!\n" $_func
        return 1
    fi
    _astr=$(declare -p "$_argDefsArray")
    eval "readonly -A _argDefs="${_astr#*=}
    shift

    # grab the Values Array String and create an array from it...
    local _aStrName=$1
    if [ -z "$_aStrName" -o "${_aStrName:0:2}" == '--' ] ; then
        printf "%s: Values array not provided!\n" $_func
        return 1
    fi
    eval "declare -A _argVals="${!_aStrName}
    shift

    local param
    local pname
    local pval
    local pcomps
    local ctlstr
    local controls
    local ctl_multi
    local ctl_req
    local ctl_list
    local inList
    local sreq
    local smulti
    local slist

    inList=''
    for param in $@ ; do
        if [[ $param =~ (\[[0-9\.-]+\]) ]] ; then
            _lno=${BASH_REMATCH[1]}
            param=${param/\[+([0-9])\]/}
            _func=$_label$_lno
        fi
        if [ "$inList" == '' ] ; then
            if [ ${#param} -lt 3 ] ; then
                show_error "%s: argument too short - %d\n" $_func ${#param}
                return 1
            fi
            if [ ${param:0:2} != '--' ] ; then
                show_error "%s: argument %s must be prefixed by --\n" $_func $param
                return 1
            fi
            # strip off the leading '--'
            param=${param:2}
            tprint "$DEBUG_FLAG" "%s: param=%s\n" $_func "$param"
            pcomps=(${param/=/ })

            if [ ${#pcomps[@]} -eq 0 -o ${#pcomps[@]} -gt 2 ] ; then
                show_error "%s(%d): bad format '%s'\n" "${#pcomps[@]}" $_func $param
                return 1
            fi

            if [[ ! $param =~ .*\..*= ]] ; then
                ctlstr=${_argDefs[${pcomps[0]}]}
                controls=(${ctlstr//,/ })
                if [ -z "$ctlstr" ] ; then
                    show_error "%s: ERROR invalid parameter(1): %s\n" $_func ${pcomps[0]}
                    return 1
                fi
                ctl_req=${controls[0]}
                ctl_multi=${controls[1]}
                ctl_list=${controls[2]}
            else
                ctl_req='optional'
                ctl_multi='single'
                ctl_list='list'
            fi
            if [ -z "$ctl_req" ] ; then
                show_error "%s: ERROR Invalid parameter(2): %s\n" $_func ${pcomps[0]}
                return 1
            fi
            if [ -z "$ctl_multi" ] ; then
                show_error "%s: ERROR Invalid parameter(3): %s\n" $_func ${pcomps[0]}
                return 1
            fi
            if [ -z "$ctl_list" ] ; then
                show_error "%s: ERROR Invalid parameter(4) for parameter: %s\n" $_func ${pcomps[0]}
                return 1
            fi

            sreq=${ctl_req:0:1}
            smulti=${ctl_multi:0:1}
            slist=${ctl_list:0:1}

            if [ ${#pcomps[@]} -eq 1 ] ; then
                if [ ! -z "${controls[2]}" -a "${controls[2]}" != "novalue" ] ; then
                    show_error "%s: ERROR Missing value for parameter: %s (%s)\n" $_func ${pcomps[0]} ${controls[2]}
                    return 1
                fi
            elif [ ${#pcomps[@]} -ne 2 ] ; then
                printf "%s: bad format '%s' only %d parts\n" $_func $param ${#pcomps[@]}
                return 1
            fi

            pname=${pcomps[0]}
            pval=${pcomps[1]}
            if [ ! -z "${controls[2]}" -a  "${controls[2]}" == "novalue" ] ; then
                pval="PRESENT"
            fi

            printf "%s: pname='%s' delim=%s pval=%s\n" $_func $pname ${pval:0:1} $pval
            if [ "${pval:0:1}" == "}" ] ; then
                show_error "%s: ERROR %s... leading '}' outside list\n" $_func $pname
                return 1
            fi
            if [ "${pval:0:1}" == "{" ] ; then
                if [ $ctl_list == 'nolist' ] ; then
                    show_error "%s: ERROR %s... List not allowed using {}s\n" $_func $pname
                    return 1
                fi
                if [ "$inList" != '' ] ; then
                    show_error "%s: ERROR %s... leading '{' within list\n" $_func $pname
                    return 1
                fi
                inList=${pval:0:1}
                pval=${pval:1}
            fi
            if [ "$inList" == '' -a "${pval:${#pval}-1:1}" == '}' ] ; then
                show_error "%s: ERROR trailing '}' outside list... %s (%s)\n" $_func $pname "$inList"
                return 1
            fi
        else
            pval=$param
            if [ ! -z "${controls[2]}" -a  "${controls[2]}" == "novalue" ] ; then
                pval="PRESENT"
            fi
        fi
         printf "%s: *** param=%s pname=%s pval=%s inList=(%s)\n" $_func "$param" "$pname" "$pval" $inList
        if [ $ctl_multi == "single" ] ; then
            if [ "$inList" == '' -a ! -z "${_argVals[${pname}]}" ] ; then
                show_error "%s: Parameter %s present more than once\n" $_func $pname
                return 1
            fi
        fi
        if [ "$inList" != '' ] ; then
            if [ "${pval:${#pval}-1:1}" == '}' ] ; then
                pval=${pval:0:-1}
                inList=''
            fi
            if [ "${pval:${#pval}-1:1}" == '{' ] ; then
                show_error "%s: Parameter %s, { present more than once\n" $_func $pname
                return 1
            fi
        fi
        if [ -z "${_argVals[$pname]}" ] ; then
            _argVals[$pname]="$pval"
        else
            _argVals[$pname]="${_argVals[$pname]} $pval"
        fi
        tprint "$DEBUG_FLAG" "%s: %s(%s,%s,%s,%s) -> %s\n" $_func $pname $sreq $smulti $slist \
            "$inList" "${_argVals[$pname]}"
    done
    if [ "$inList" != '' ] ; then
        show_error "%s: param=%s list not terminated...\n" $_func $pname
        return 1
    fi

    # serialize the associative array into a string...
    _astr=$(declare -p _argVals)
    _astr="${_astr#*=}"
    eval $_aStrName='${_astr}'
    return 0
}

#
# check_mandatory_args:
#
function check_mandatory_args {
    local _func='check_mandatory_args'
    local _argDefsArray=$1
    local _argValsArray=$2
    local _argDefs
    local _argVals

    if [ -z "$_argDefsArray" ] ; then
        printf "%s: No Argument Definitions Passed!!!\n"
        return 1
    fi
    local _var=$(declare -p "$_argDefsArray")
    eval "readonly -A _argDefs="${_var#*=}

    if [ -z "$_argValsArray" ] ; then
        printf "%s: No Argument Vaues Passed!!!\n"
        return 1
    fi
    local _var=$(declare -p "$_argValsArray")
    eval "readonly -A _argVals="${_var#*=}

    local key
    local ctlstr
    local controls

    for key in ${!_argDefs[@]} ; do
        ctlstr=${_argDefs[$key]}
        ctlstr=${ctlstr//,/ }
        controls=($ctlstr)
        if [ -z "$ctlstr" ] ; then
            show_error "%s: ERROR Missing parameter metadata for %s\n" $_func $key
            return 1
        fi
        if [ ! -z "${_argDefs[$key]}" ] ; then
            ctlstr=${_argDefs[$key]}
            controls=(${ctlstr//,/ })
            if [ ! -z "${controls[0]}" ] && \
               [ "${controls[0]}" == "mandatory" ]  && \
               [ -z "${_argVals[$key]}" ] ; then
                show_error "%s: Missing mandatory argument=%s\n" $_func $key
                return 1
            fi
        fi
    done
    return 0
}

#
# proc_file_args:
#
# $1 - Path to config file
# $2 - Argument definitions associative array
# $3 - Argument value ass. array string name
#
function proc_file_args {
    local _func=${FUNCNAME}
    local _file=$1
    local _lno=1
    local _cno
    local _buf
    local _line
    local _fileVals
    local _argDefsName=$2
    local _argValStrName=$3
    local _astr=''
    local _fvstr=''

    if [ -z "$_file" ] ; then
        printf "%s: config file not provided\n" $_func
        return 1
    fi
    if [ ! -f "$_file" ] ; then
        show_error "%s: Missing config file '%s'\n" $_func $_file
        return 1
    fi
    if [ -z "$_argDefsName" ] ; then
        printf "%s: Missing argDefs\n" $_func
        return 1
    fi
    if [ -z "$_argValStrName" ] ; then
        printf "%s: Missing argVals\n" $_func
        return 1
    fi

    while read _line ; do
        _cno=$_lno
        _lno=$((_lno+1))
        if [[ $_line =~ [[:space:]]*# ]] ; then
            continue
        fi
        if [[ $_line =~ ^[[:space:]]*$ ]] ; then
            continue
        fi
        # Make this line look like a commandline argument...
        _line=${_line/*([[:space]])/}
        _line='['$_cno']--'$_line
        _buf="$_buf $_line"
    done < $_file

    process_args 'file' $_argDefsName _fvstr "$_buf"
    if [ $? -ne 0 ] ; then
        printf "%s: Bad format for cfgfile=%s\n" $_func $_file
        return 1
    fi

    # create an array from the array string...
    tprint "$DEBUG_FLAG" "%s: FV=%s\n" $_func "$_fvstr"
    eval "readonly -A _fileVals="${_fvstr}

    # Construct the Arg Values array from the passed string name
    eval "declare -A _curVals="${!_argValStrName}

    for _key in ${!_fileVals[@]} ; do
        if [ ! -z "$_key" -a -z "${_curVals[$_key]}" ] ; then
            if [ ! -z "${_fileVals[$_key]}" ] ; then
                _curVals[$_key]="${_fileVals[$_key]}"
            fi
        fi
    done

    # serialize the array back into a string
    _astr=$(declare -p _curVals)
    _astr=${_astr#*=}
    eval "$_argValStrName="${_astr}
    return 0
}

#
# process_command:
#
# $1 - IN: Command to process
# $* - IN: Arguments
#
function process_command {
    local _func=${FUNCNAME}
    local _cmd=$1
    local _entries
    local _cmdfunc

    local _cmdDefs
    declare -A array _cmdDefs

    printf "%s: %s\n" $_func "$*"

    # entry format: <func-name>,<cmd-help-array>
    # where <cmd-help-array> is a global usage array
    _cmdDefs['create']='do_cmd_create,aCreateHelp'
    _cmdDefs['test']='do_cmd_iso_test,aTestHelp'
    _cmdDefs['rpm2iso']='do_cmd_rpm_to_iso,aRpm2IsoHelp'
    _cmdDefs['show']='do_cmd_show_params,aShowHelp'
    _cmdDefs['repo']='do_cmd_repo,aRepoHelp'

    if [ -z "$_cmd" ] ; then
        printf "No command provided\n"
        print_cmd_help _cmdDefs
        return 1
    fi

    if [ -z "${_cmdDefs[$_cmd]}" ] ; then
        printf "Invalid Command: %s\n" "$_cmd"
        print_cmd_help _cmdDefs
        return 1
    fi

    _entries=(${_cmdDefs[$_cmd]//,/ })
    _cmdfunc=${_entries[0]}
    _help=${_entries[1]}
    printf "Matched command %s; invoke func %s\n" $_cmd "${_cmdfunc}"

    shift
    echo ${_cmdfunc} $*
    ${_cmdfunc} "$@"

    return 0
}

#
# tprint: printf if arg 1 is true
#
# $1 - IN: should this be printed
# $2 - IN: format string
# $3 - IN: additonal strings
#
function tprint {
    local _fmt
    if [ -z "$1" ] ; then
        return 1
    fi
    if [ $1 -eq 0 ] ; then
        shift
        _fmt=$1
        if [ -z "$_fmt" ] ; then
            return 1
        fi
        shift
        printf "$_fmt" "$@"
    fi
    return 0
}

#
# output_n_chars:
#
# $1 - IN character
# $2 - IN count
# $3 - IN suppress trailing LF
#
function output_n_chars() {
   local i=0
   local j="$2"
   while [ $i -lt $j ] ; do
       printf "$1"
       i=$((i+1))
   done
   if [ -z "$3" -o "$3" == 'LF' ] ; then
       printf "\n"
   fi
}

#
# print_error:
#
function print_error {
  local _len

  if [ ! -z "$1" ] ; then
      _len=${#1}
      _len=$((_len+4))
      output_n_chars '*' $_len
      printf "* $1\n"
      output_n_chars '*' $_len
  fi
}

#
# exit_on_fail:
#
function exit_on_fail {
   if [ ! -z "$1" -a "$1" != "" ] &&
      [ ! -z "$2" ] ; then
      if [ $2 -ne 0 ] ; then
          print_error "$1 FAILED... Exiting"
          cleanup_mounts MKISO_VALS
          exit $2
      fi
   fi
}

#
# check_path_safe:
#
# $1 - IN: path to ckech
# $2 - Invoking funcion name
#
# Check to see if a path is safe (as rm -rf may be done on it).
#
# While a chroot environment might be a safer solution, someone
# has to cleanup/delete the chroot environment and at the moment
# its not clear a normal user can remove some of the files in the
# chroot directory -- requiring the use of sudo, which sort of
# defeats the purpose of chroot given that only yum install
# would be using this envirnment...
#
function check_path_safe {
    local _path=$1
    local _func=$2
    local _myfunc=${FUNCNAME}

    # can't be empty
    if [ -z "$_path" ] ; then
        printf "%s: empty path!\n" $_myfunc
        return 1
    fi
    # can't be empty
    if [ -z "$_func" ] ; then
        printf "%s: caller not provided!\n" $_myfunc
        return 1
    fi
    # soft links not allowed
    if [ -L "$_path" ] ; then
        printf "%s: soft link %s\n" $_func "$_path"
        return 1
    fi
    # root could be bad, just saying
    if [ '/' -ef "$_path" ] ; then
        printf "%s: root dir not allowed!\n" $_func
        return 1
    fi
    # homedir could be bad also
    if [ "$_path" == "$HOME" ] ; then
        printf "%s: %s cannot be user home\n" $_func $_path
        return 1
    fi
    # exec path could be bad also
    if [ "$_path" == "$MKISO_EXEC_PATH" ] ; then
        printf "%s: %s cannot be mkiso.sh directory\n" $_func $_path
        return 1
    fi
    if [ -z "$WORKSPACE" ] ; then
        printf "%s: WORKSPACE cannot be empty\n" $_func $_path
        return 1
    fi
    #  path must be in the workspace
    if [[ ! "$_path" =~ ^$WORKSPACE ]] ; then
        printf "%s: %s must be child of %s\n" $_func $_path $WORKSPACE
        return 1
    fi
    # if the path exists, check for the touch file
    # otherwise check for parent owners...
    if [ -d "$_path" ] ; then
        _touch="$_path/$MKISO_WORKSPACE_ID"
        if [ -z "$_touch" ] ; then
            printf "%s: Empty touch path\n" $_func
            return 1
        fi
        if [ ! -e "$_touch" ] ; then
            printf "%s: %s missing touchfile=%s\n" $_func "$_path" \
                   "$MKISO_WORKSPACE_ID"
            return 1
        fi
        if [ ! -O  "$_touch" ] ; then
            printf "%s: %s wrong owner for '%s'\n" $_func "$_path" \
                   "$MKISO_WORKSPACE_ID"
            return 1
        fi
    else
        # you must own the directory, or a parent if it doesnt exist...
        while [[ "$_path" =~ ^$WORKSPACE ]] ; do
            printf "%s: checking owner of %s\n" $_func "$_path"
            if [ ! -e "$_path" ] ; then
                _path=`dirname $_path
           continue`
            fi
            if [ ! -O "$_path" ] ; then
                printf "%s: not owner of %s\n" $_func "$_path"
                return 1
            else
                break
            fi
        done
    fi

    return 0
}

#
# purge_mkiso_dir:
#
# $1 - IN: Name of path to remove
# $2 - IN: invoking function name
# $3 - IN: 'sudo' => do sudo... Anything else does not.
#
# Removes directories and files which form the yum cache state and
# downloaded RPMs.
#
# NOTE: It would be preferable to never use sudo, but the yum
#       'pseudo chroot' environment alters the files so that even if
#       owned by a non-root user they cannot be deleted w/o using sudo.
#       ls/chattr does not help.  Neither does sudo restorecon -R.
#
# NOTE: rm -rf apparently run in the background or something, as w/o
#       renaming the installroot directory before removing it, the
#       yum install run milli/microseconds later was still seeing some
#       of the files that were presumably deleted, playing havoc with
#       the --installroot yum cache state.
#
function purge_mkiso_dir {
    local _myfunc=${FUNCNAME}
    local _mvcmd=''
    local _rmcmd=''
    local _path_owner=''
    local _path=$1
    local _func=$2
    local _dosudo=$3
    local _tmp_path=''

    if [ -z "$_path" ] ; then
        printf "%s: Missing MKISO path\n" $_myfunc
        return 1
    fi

    if [ -z "$_func" ] ; then
        printf "%s: Missing Func\n" $_myfunc
        return 1
    fi

    if [ -z "$_dosudo" ] ; then
        _dosudo='nosudo'
    fi
    if [ "$_dosudo" != 'sudo' -a "$_dosudo" != 'nosudo' ] ; then
        printf "%s: Invalid SUDO parameter=%s\n" $_myfunc "$_dosudo"
        return 1
    fi

    check_path_safe "$_path" "$_func:$_myfunc"
    if [ $? -ne 0 ] ; then
        printf "%s: path not safe: %s\n" $_myfunc "$_path"
        return 1
    fi

    _mvcmd='mv -f'
    _rmcmd='rm -rf'
    if [ -d "$_path" ] ; then
        if [ "$_dosudo" == 'sudo' ] ; then
            _mvcmd='sudo mv -f'
            _rmcmd='sudo rm -rf'
        fi
        _delpath="$_path".old
        printf "%s: %s %s -> %s\n" $_myfunc "$_mvcmd" "$_path" "$_delpath"
        $_mvcmd "$_path" "$_delpath"
        if [ $? -ne 0 ] ; then
            printf "%s: %s mv FAILED (%s)\n" $_myfunc "$_mvcmd" "$_delpath"
            return 1
        fi
        printf "%s: %s %s\n" $_myfunc "$_rmcmd" "$_delpath"
        $_rmcmd "$_delpath"
        if [ $? -ne 0 ] ; then
            printf "%s: %s FAILED (%s)\n" $_myfunc "$_rmcmd" "$_delpath"
            return 1
        fi
    fi

    return 0
}

#
# add_to_list
#
function add_to_list {
   local _name=$1
   local _value=$2
   local _delim=$3

   if [ -z "$_name" -o "$_name" == "" ] ; then
        return 1
   fi
   if [ -z "$_value" -o "$_value" == "" ] ; then
        return 1;
   fi
   if [ -z "$_delim" -o "$_delim" == "" ] ; then
        _delim=' '
   fi

   if [ -z "${!_name}"  -o "${!_name}" == "" ] ; then
        # prevent globbing..
        eval ${_name}='"${_value}"'
   else
        eval $_name='"${!_name}$_delim$_value"'
   fi

   return 0
}


#
# gen_yum_conf_from_file
#
# Generates a yum.conf file with the repo definitions specfied in $1.
# The correct formatting of $1 is the responsibility of the caller.
# The resulting file is saved in $2
#
# $1 -  IN: Yum Repository file
# $2 - OUT: Yum configfile
#
function gen_yum_conf {
   local _yumRepoPath=$1
   local _func=${FUNCNAME}
   local _yumConfBase=''

   if [ -z "$_yumRepoPath" ] ; then
       printf "%s: ERROR yumRepoFile not provided\n" $_func
       return 1
   fi
   if [ ! -f "$_yumRepoPath" ] ; then
       printf "%s: ERROR yumRepoFile not found\n" $_func
       return 1
   fi
   if [ -z "$_yumConfPath" ] ; then
       printf "%s: ERROR yumConfFile not provided\n" $_func
       return 1
   fi
   _yumConfBase=`dirname $_yumConfPath`
   if [ ! -z "$_yumConfBase" -a ! -d "$_yumConfBase" ] ; then
       printf "%s: ERROR missing target directory %s\n" $_func $_yumConfPath
       return 1
   fi

   printf "%s\n\n" "$YUM_CONF_FILE_SEED" > $_yumConfPath
   cat "$_yumRepoPath" >> $_yumConfPath

   return 0
}


#
# gen_yum_conf_from_array:
#
# Create a single repo entry for a yum.conf file
#
# $1  IN: Ass array
# $2  IN: Output file path
# $3  IN: '' or 'append'
#
function gen_yum_conf_from_array {
  local _func=${FUNCNAME}
  local _arrayDef=$1
  local _outfile=$2
  local _append=$3

  if [ -z "$_arrayDef" ] ; then
      printf "%s: ERROR values not provided!\n" $_func
      return 1
  fi
  if [ -z "$_outfile" ] ; then
      printf "%s: ERROR yum.conf target not provided!\n" $_func
      return 1
  fi

  declare -A array YUM_REPO_FORMATS
  YUM_REPO_FORMATS['YUM_REPO_ID']='[%s]'
  YUM_REPO_FORMATS['YUM_REPO_NAME']='name=%s'
  YUM_REPO_FORMATS['YUM_FAILOVER_METHOD']='failovermethod=%s'
  YUM_REPO_FORMATS['YUM_SSL_VERIFY']='sslverify=%s'
  YUM_REPO_FORMATS['YUM_SSL_CLIENT_PEM']='sslclientcert=%s'
  YUM_REPO_FORMATS['YUM_BASE_URL']='baseurl=%s'
  YUM_REPO_FORMATS['YUM_ENABLED']='enabled=%s'
  YUM_REPO_FORMATS['YUM_METEDATA_EXPIRE']='metadata_expire=%s'
  YUM_REPO_FORMATS['YUM_GPG_CHECK']='gpgcheck=%s'
  YUM_REPO_FORMATS['YUM_SKIP_UNAVAIL']='skip_if_unavailable=%s'

  _var=$(declare -p "$_arrayDef")
  eval "readonly -A _vals="${_var#*=}

  if [ -z "${_vals['YUM_REPO_ID']}" ] ; then
      printf "%s: YUM_REPO_ID must be provided!\n" $_func
      return 1
  fi
  if [ -z "${_vals['YUM_REPO_NAME']}" ] ; then
      printf "%s: YUM_REPO_NAME must be provided!\n" $_func
      return 1
  fi
  if [ -z "${_vals['YUM_BASE_URL']}" ] ; then
      printf "%s: YUM_BASE_URL must be provided!\n" $_func
      return 1
  fi
  if [ -z "${_vals['YUM_ENABLED']}" ] ; then
      printf "%s: YUM_ENABLED must be provided!\n" $_func
      return 1
  fi

  local _yumConfBase=`dirname $_outfile`
  if [ ! -z "$_yumConfBase" -a ! -d "$_yumConfBase" ] ; then
      printf "%s: ERROR missing target-dir %s\n" $_func $_yumConfBase
      return 1
  fi

  if [ -z "$_append" -o "$_append" != 'append' ] ; then
       printf "%s\n\n" "$YUM_CONF_FILE_SEED" > "$_outfile"
  else
      if [ ! -f "$_outfile" ] ; then
          printf "%s: ERROR missing target file %s\n" $_func "$_outfile"
          return 1
      fi
      print "\n" >> $_outfile
  fi

  printf "${YUM_REPO_FORMATS[YUM_REPO_ID]}\n" "${_vals[YUM_REPO_ID]}" >> $_outfile
  printf "${YUM_REPO_FORMATS[YUM_REPO_NAME]}\n" "${_vals[YUM_REPO_NAME]}" >> $_outfile
  for _key in ${!YUM_REPO_FORMATS[@]} ; do
     if [ "$_key" == "YUM_REPO_ID" ] || \
         [ "$_key" == "YUM_REPO_NAME" ] ; then
         continue
     fi
     if [ ! -z "${_vals[$_key]}" ] ; then
         printf "${YUM_REPO_FORMATS[$_key]}\n" "${_vals[$_key]}" >> $_outfile
     fi
  done

  return 0
}

#
# copy_repo_config:
#
# $1 - IN: Parameters associative array name
#
function copy_repo_config {
    local _func=${FUNCNAME}
    local _repodata
    local _an=$1

    if [ -z "$_an" ] ; then
        printf "%s: Missing Parameters Array\n" $_func
        return 1
    fi

    local _astr=$(declare -p "$_an")
    eval "readonly -A _repodata"=${_astr#*=}

    local _inst_root="${_repodata[yum_install_path]}"
    local _yum_repo_src_path="${_repodata[yum_repo_src_path]}"
    local _yum_repo_dest_path="${_repodata[yum_repo_dest_path]}"
    local _yum_repo_src_conf="${_repodata[yum_repo_src_conf]}"
    local _yum_repo_dest_conf="${_repodata[yum_repo_dest_conf]}"
    local _yum_pki_src_path="${_repodata[yum_pki_src_path]}"
    local _yum_pki_dest_path="${_repodata[yum_pki_dest_path]}"

    if [ -z "$_inst_root" ] ; then
        printf "%s: Missing yum install root\n" $_func
        return 1
    fi
    if [ -z "$_yum_repo_src_conf" ] ; then
        printf "%s: Missing src yum.conf path\n" $_func
        return 1
    fi
    if [ -z "$_yum_repo_dest_conf" ] ; then
        printf "%s: Missing dest yum.conf path\n" $_func
        return 1
    fi

    printf "%s: inst_root=          %s\n" $_func "${_repodata[yum_install_path]}"
    printf "%s: yum_repo_src_path=  %s\n" $_func "${_repodata[yum_repo_src_path]}"
    printf "%s: yum_repo_dest_path= %s\n" $_func "${_repodata[yum_repo_dest_path]}"
    printf "%s: yum_repo_src_conf=  %s\n" $_func "${_repodata[yum_repo_src_conf]}"
    printf "%s: yum_repo_dest_conf= %s\n" $_func "${_repodata[yum_repo_dest_conf]}"
    printf "%s: yum_pki_src_path=   %s\n" $_func "${_repodata[yum_repo_src_path]}"
    printf "%s: yum_pki_dest_path=  %s\n" $_func "${_repodata[yum_repo_dest_path]}"

    local _file
    local _repo_files
    local _repo_tgt_file
    local _cerfiles
    local _certsrc
    local _certdir
    local _certpath

    # initialize paths
    local _yum_repo_tgt_path="${_inst_root}${_yum_repo_dest_path}"
    local _yum_conf_tgt_file="${_inst_root}${_yum_repo_dest_conf}"
    local _yum_conf_tgt_dir=`dirname "$_yum_conf_tgt_file"`

    printf "%s: yum_repo_tgt_path= %s\n" $_func "${_yum_repo_tgt_path}"
    printf "%s: yum_conf_tgt_file= %s\n" $_func "${_yum_conf_tgt_file}"
    printf "%s: yum_conf_tgt_dir=  %s\n" $_func "${_yum_conf_tgt_dir}"

    if [ -e $_yum_repo_tgt_path ] ; then
	printf "%s: _yum_repo_tgt_path=%s EXISTS!!!\n" $_func "${_yum_repo_tgt_path}"
        # show_error "%s: _yum_repo_tgt_path=%s EXISTS!!!\n" $_func "${_yum_repo_tgt_path}"
        return 1
    fi

    # copy yum conf
    if [ ! -d "$_yum_conf_tgt_dir" ] ; then
        printf "%s: mkdir -p %s\n" $_func "$_yum_conf_tgt_dir"
        mkdir -p "$_yum_conf_tgt_dir"
        if [ $? -ne 0 ] ; then
            printf "%s: Create Directory FAILED '%s'\n" $_func "$_yum_conf_tgt_dir"
            return 1
        fi
    fi
    printf "%s: cp -f %s -> %s\n" $_func "$_yum_repo_src_conf" "$_yum_conf_tgt_file"
    # sudo cp -f "$_yum_repo_src_conf" "$_yum_conf_tgt_file"
    cp -f "$_yum_repo_src_conf" "$_yum_conf_tgt_file"
    if [ $? -ne 0 ] ; then
        printf "%s: Copy FAILED '%s'\n" $_func "$_yum_repo_src_conf"
        return 1
    fi

    # initialize yum.repos.d
    local _repo_files=""
    if [ -d "${_yum_repo_src_path}" ] ; then
        _repo_files=(`ls ${_yum_repo_src_path}/*.repo`)
    fi

    for _file in "${_repo_files[@]}" ; do
        if [ -z "$_file" -o -d "$_file" ] ; then
            continue
        fi
        _repo_tgt_file=`basename "$_file"`
        _repo_tgt_file="${_yum_repo_tgt_path}/$_repo_dest_file"
        if [ ! -d "$_yum_repo_tgt_path" ] ; then
            printf "%s: mkdir -p %s\n" $_func "$_yum_repo_tgt_path"
            mkdir -p "$_yum_repo_tgt_path"
            if [ $? -ne 0 ] ; then
                printf "%s: Create Directory FAILED '%s'\n" $_func "$_yum_repo_tgt_path"
                return 1
            fi
        fi
        printf "%s: cp -f %s -> %s\n" $_func "$_file" "${_repo_tgt_file}"
        # sudo cp -f "$_file" "${_repo_tgt_file}"
        cp -f "$_file" "${_repo_tgt_file}"
        if [ $? -ne 0 ] ; then
            printf "%s: Copy FAILED '%s'\n" $_func "$_file"
            return 1
        fi

        # check if any certificate files are required...
        _certfiles=(`awk 'match($0, /^sslclientcert=(.*?)$/, matches) {print matches[1]}' ${_file}`)
        for _certsrc in "${_certfiles[@]}" ; do
            _certdir=`dirname ${_certsrc}`
            _certdir="${_inst_root}${_certdir}"
            _certpath="${_inst_root}${_certsrc}"
            printf "%s: ...certsrc=%s\n" $_func "$_certsrc"
            printf "%s: ...certdir=%s\n" $_func "$_certdir"
            printf "%s: ...certpath=%s\n" $_func "$_certpath"
            if [ ! -d "$_certdir" ] ; then
                printf "%s: ...mkdir -p %s\n" $_func "$_certdir"
                mkdir -p "$_certdir"
                if [ $? -ne 0 ] ; then
                    printf "%s: ...Create Directory FAILED '%s'\n" $_func "$_certdir"
                    return 1
                fi
            fi
            printf "%s: ...Copy %s -> %s\n" $_func "$_certsrc" "$_certpath"
            if [ -f "$_certsrc" ] ; then
		cp -f "$_certsrc" "$_certpath"
		if [ $? -ne 0 ] ; then
                    printf "%s: ...Copy FAILED '%s'\n" $_func "$_certsrc"
                    return 1
		fi
            else
		printf "%s: skipping %s -- not found\n" $_func "$_certpath"
	    fi
        done
    done

    #  Load any public gpg keys...
    local _fn
    local _key
    local _keys=""
    local _key_tgt_path
    if [ ! -z "$_yum_pki_src_path" ] && \
       [ -d "$_yum_pki_src_path" ] ; then
        _keys=(`ls ${_yum_pki_src_path}/*`)
    fi
    _key_tgt_path="${_inst_root}${_yum_pki_dest_path}"
    if [ ${#_keys} -gt 0 ] && \
       [ -z "$_key_tgt_path" ] ; then
        printf "%s: source keys but no dest-path\n" $_func
        return 1
    fi
    for _key in "${_keys[@]}" ; do
        if [ -z "$_key" -o -d "$_key" ] ; then
             continue
        fi
        if [ ! -d "$_key_tgt_path" ] ; then
            printf "%s: mkdir -p %s\n" $_func "$_key_tgt_path"
            mkdir -p "$_key_tgt_path"
            if [ $? -ne 0 ] ; then
                printf "%s: Create Directory FAILED '%s'\n" $_func "$_key_tgt_path"
                return 1
            fi
        fi
        _fn=`basename $_key`
        _key_target="$_key_tgt_path/$_fn"
        printf "%s: copy %s -> %s\n" $_func "$_key" "$_key_target"
        # sudo cp -f "$_key" "$_key_target"
        cp -f "$_key" "$_key_target"
        if [ $? -ne 0 ] ; then
            printf "%s: copy %s FAILED\n" $_func "$_key"
            return  1
        fi
        printf "%s: sudo rpm --root %s --import %s\n" $_func $_inst_root $_key
        sudo rpm --root "$_inst_root" --import "$_key"
        if [ $? -ne 0 ] ; then
            printf "%s: rpm import FAILED\n" $_func "$_key"
            return 1
        fi
    done

    printf "%s: REPO SETUP COMPLETE\n" $_func
    return 0
}

#
# move_groups_to_font:
#
# @ entries are moved in front of non-@-entries resulting in:
#  @entries followed by non-sorted _glist entries
#
# If desired, sorting of @entries can be achieved by:
# IFS=$'\n' ; _glist=($(sort -u <<< "${_glist[*]}")) ; unset IFS
#
# This is done to ease the pain of newer packages with newer dependencies
# being installed *before* packages with older dependencies
#
# Note: Group syntax for complex names is "@Group Name" for yum
#        and @Group Name for kickstart files
#
# $1  IN/OUT: name of array variable
#
function move_groups_to_front {
  local _func=${FUNCNAME}
  local _listName=$1

  if [ -z "$_listName" -o "$_listName" == "" ] ; then
      printf "%s: ERROR no list name provided\n" $_func
      return 1
  fi

  local _pkg
  local _glist=''
  local _non_glist=''
  local _pkglist

  _pkglist=(${!_listName})

  for _pkg in ${_pkglist[@]} ; do
      if [ ${#_pkg} -gt 2 ] ; then
          if [ ${_pkg:0:1} == '@' ] ; then
               add_to_list _glist ${_pkg}
          elif [ ${_pkg:0:1} == '~' ] ; then
               add_to_list _non_glist ${_pkg}
          elif [ ${_pkg:0:1} == '+' ] ; then
               add_to_list _non_glist ${_pkg}
          elif [[ $_pkg =~ '(@.*)' ]] ; then
                add_to_list _glist {BASH_REMATCH[1]}
          else
               add_to_list _non_glist ${_pkg}
          fi
      fi
   done

   printf "%s: %s=%s\n" $_func $_listName "\"$_glist $_non_glist\""
   eval "$_listName=\"$_glist $_non_glist\""

   return 0
}

function pre_process_rpm_list() {
  local      _func=${FUNCNAME}
  local      _list=$1
  local  _rpm_list=$2
  local  _grp_list=$3
  local _copy_list=$4

  local _file
  local _filestr
  local _files

  if [ -z "$_list" ] ; then
      printf "%s: input list not provided\n" $_func
      return 1
  fi
  if [ -z "$_rpm_list" ] ; then
      printf "%s: output rpm list not provided\n" $_func
      return 1
  fi
  if [ -z "$_grp_list" ] ; then
      printf "%s: output group list not provided\n" $_func
      return 1
  fi
  if [ -z "$_copy_list" ] ; then
      printf "%s: output copy list not provided\n" $_func
      return 1
  fi

  # empty lists
  eval ${_rpm_list}=""
  eval ${_grp_list}=""
  eval ${_copy_list}=""

  # move groups tp front of list...
  move_groups_to_front ${_list}

  for _file in ${!_list} ; do
      echo "process $_list $_file..."
      if [ $_file == '' -o ${#_file} -le 2 ] ; then
          continue
      fi
      # '-' prefix is relevant only to kickstart; just strip it
      if [ "${_file:0:1}" == "-" ] ; then
          _file=${_file:1}
      fi
      if [ "${_file:0:1}" == "+" ] ; then
          add_to_list ${_rpm_list} ${_file:1}
          add_to_list ${_copy_list} ${_file:1}
      elif [ "${_file:0:1}" == "@" ] ; then
          add_to_list ${_rpm_list} ${_file}
      elif [ "${_file:0:2}" == "\'@" ] ; then
          add_to_list ${_grp_list} ${_file:1}
      elif [ "${_file:0:1}" == "~" ] ; then
          _filestr=`ls -1t ${_file:1}*.rpm`
          if [  $? -eq 0 -a ! -z "$_filestr" ] ; then
              _files=($_filestr)
              if [ ${#_files[@]} -gt 0 ] ; then
                 add_to_list ${_rpm_list} ${_files[0]}
                 add_to_list ${_copy_list} ${_files[0]}
              else
                  printf "%s: ERROR No rpm match-2 for: $_file\n" $_func
                  return 1
              fi
           else
               printf "%s: ERROR No rpm match-1 for: $_file\n" $_func
               return 1
           fi
      else
          add_to_list ${_rpm_list} ${_file}
      fi
  done

  if [ -z "${!_grp_list}" -o "${!_grp_list}" == "" ] &&
     [ -z "${!_rpm_list}" -o "${!_rpm_list}" == "" ] ; then
     printf "%s: Extracted No RPMs / GROUPs!\n" $_func
  fi

  return 0
}


# yum_download:
#
# $1 - IN: Name of parameters assoc. array
# $2 - IN: install or no-install (if not provided defaults to no-install)
# $3 - IN: list of args to get packages from
#
# Warning: yum --installroot, behaves in odd ways.  Even using --config,
#          populating the installroot with repo and keys, it seems that
#          yum can go outside the root to get repo info. The test_iso_install()
#          function proves that a ISO-repo created in the installroot is processed,
#          but repos from outside the installroot, on the VM in use, are also
#          considered.  The only way to be sure it seems is to exclude every repo
#          and then enable only the ones from the chroot env:
#
#          yum --installroot=/path/to/my/root --disablerepo=* --enablerepo=mkiso-*
#
#          The --disablerepo and --enablerepo arguments are only currently used
#          for mkiso.sh test (test_iso_install function)  -- as the mkiso.sh rpm2cpio
#          and mkiso.sh create, do not care as what repo definitions are used, as
#          as long as they work.
#
function yum_download {
  local _func=${FUNCNAME^^}
  local _argsName=$1
  local _doInstall=$2
  local _doCopyConfig=$3
  local _pkgArgs=$4
  local _astr=''
  local _args

  if [ -z "$_argsName" ] ; then
      printf "%s: Missing Parameter List Name\n"
      return 1
  fi

  _astr=$(declare -p $_argsName)
  eval "readonly -A _args="${_astr#*=}

  output_n_chars '-' 79

  if [ -z "$_pkgArgs" ] ; then
      _pkgArgs="pkglist pkglast"
      printf "%s: Defaulting pkgArgs to: %s\n" ${_func} "${_pkgArgs}"
  fi
  _pkgArgs=(${_pkgArgs})

  local _instRootPath=${_args[yum_install_path]}
  local _rpmDloadPath=${_args[yum_rpm_path]}
 # local _instList=${_args[pkglist]}
  local _instVer=${_args[os-version]}
  local _deferInst=${_args[pkglast]}
  local _delExtra=${_args[pkgdel]}
  local _yumConfFile=${_args[yum-conf]}
  local _yum_extra_args=${_args[yum_extra_args]}
  local _iso_pattern=${_args[rpm-to-iso-pattern]}

  local _filestr=''
  local _files=()
  local _rpmList=''
  local _grpList=''
  local _copyList=''

  local _preRpmList
  local _postRpmList
  local _pat
  local _rpm

  if [ -z "$_instRootPath" ] ; then
      printf "%s: ERROR RootInstallPath not provided!\n" $_func
      return 1
  fi
  if [ ! -d "$_instRootPath" ] ; then
      printf "%s: ERROR RootInstallPath %s not found!\n" $_func $_instRootPath
      return 1
  fi
  if [ -z "$_rpmDloadPath" ] ; then
      printf "%s: ERROR RPM Download Path not provided!\n" $_func
      return 1
  fi
  if [ ! -d "$_rpmDloadPath" ] ; then
      printf "%s: ERROR RPM Download Path %s not found!\n" $_func $_rpmDloadPath
      return 1
  fi

  _popCount=0
  for _argName in ${_pkgArgs[@]} ; do
      if [ ! -z "${_args[$_argName]}" ] && \
	  [ "${_args[$_argName]}" != ""  ] ; then
	  _popCount=$((_popCount+1))
      fi
  done
  if [ ${_popCount} -eq  0 ] ; then
      printf "%s: ERROR Empty RPM/GROUP List! pkgArgs: %s\n" ${_func} ${_pkgArgs[@]}
      return 1
  fi 

#  if [ -z "$_instList" ] ; then
#      printf "%s: ERROR Empty RPM/GROUP List!\n" $_func
#      return 1
#  fi

  if [ -z "$_doInstall" -o "$_doInstall" == "" ] ; then
       _doInstall="no-install"
  fi
  if [ "$_doInstall" != "install" -a "$_doInstall" != "no-install" ] ; then
      printf "%s: ERROR Invalid Install directive - $_doInstall!\n" $_func
      return 1
  fi

  if [ -z "$_doCopyConfig" -o "$_doCopyConfig" == "" ] ; then
       _doCopyConfig="copy-config"
  fi
  if [ "$_doCopyConfig" != "copy-config" -a "$_doCopyConfig" != "no-copy-config" ] ; then
      printf "%s: ERROR Invalid copy-config directive - $_doCopyConfig!\n" $_func
      return 1
  fi

  #printf "%s(%s, %s, '%s', %s, %s)\n" $_func $_instRootPath $_rpmDloadPath \
  #    "$_instList $_deferInst" $_instVer $_doInstall

  printf "%s(%s, %s, '%s', %s, %s, %s)\n" $_func $_instRootPath $_rpmDloadPath \
      "${_pkgArgs[@]}" $_instVer $_doInstall $doCopyConfig

  # initialize install root to use repo config
  if [ "$_doCopyConfig" != "no-copy-config" ] ; then
      copy_repo_config _args
      if [ $? -ne 0 ] ; then
	  printf "%s: copy_repo_config FAILED!\n" $_func
	  return 1
      fi
  fi

  local _rpmArgs=''
  local _grpArgs=''
  local _xtraArgs=''

  # without setting release version all sorts of things break
  if [ -z "$_instVer" ] ; then
       show_error "%s: OS Release Version is Mandatory!\n" ${_func}
       return 1
  fi

  if [[ $_instVer =~ [0-9]+ ]] ; then
      printf "%s: add_to_list _xtraArgs --releasever=%s\n" $_func $_instVer
      add_to_list _xtraArgs "--releasever=$_instVer"
  else
      printf "%s: Release Version \'%s\' Must be Numeric\n" $_func $_instVer
      return 1
  fi

  if [ "$_doInstall" != "install" ] ; then
      add_to_list _xtraArgs "--downloadonly"
  else
      add_to_list _xtraArgs "-y"
  fi

  if [ ! -z "$_yumConfFile" ] ; then
      printf "%s: add_to_list _xtraArgs --config=%s\n" $_func $_yumConfFile
      add_to_list _xtraArgs "--config=$_yumConfFile"
  fi

  # Apply any additional args from callers...
  if [ ! -z  "$_yum_extra_args" ] ; then
      printf "%s: extra_args=%s\n" $_func "$_yum_extra_args"
      add_to_list _xtraArgs "$_yum_extra_args"
      printf "%s: xtraArgs=%s\n" $_func "$_xtraArgs"
  fi

  # remember prior install-root path ownership
  local _origInstRootOwner=`stat -c %U $_instRootPath`

  # Initialize the install root cache
  local _cmd='sudo yum'
  local _cmdArgs=("makecache --installroot=$_instRootPath" "$_xtraArgs")
  printf "%s: %s %s\n" $_func "$_cmd" "${_cmdArgs[*]}"
  $_cmd ${_cmdArgs[@]}
  if [ $? -ne 0 ] ; then
      printf "%s: ERROR yum makecache FAILED!\n" $_func
      return 1
  fi

  # Do the various installs
  _cmdArgs=("--installroot=$_instRootPath" "--downloaddir=$_rpmDloadPath" "$_xtraArgs")

  local _listCount=1
  #local _pkgLists="_instList _deferInst"
  local _iso_match=''
  local _iso_path=''
  for _pkgArg in ${_pkgArgs[@]} ; do
      _pkgList=${_args[${_pkgArg}]}
      echo "${_pkgArg}->PKGLIST=${_pkgList}"
      pre_process_rpm_list _pkgList _rpmList _grpList _copyList
      if [ $? -ne 0 ] ; then
          printf "%s: pre_process_rpm_list(%s...) FAILED!\n" $_func $_pkglist
          return 1
      fi
      if [ -z "$_grpList" -o "$_grpList" == "" ] &&
         [ -z "$_rpmList" -o "$_rpmList" == "" ] ; then
          #if [ "$_pkgList" == "_instList" ] ; then
          #    printf "%s: No RPMs / GROUPs for mandatory pkglist parameter!!!\n" $_func
          #    return 1
          #else
          #    printf "%s: No RPMs / GROUPs for package list; skipping...\n" $_func
          #    continue
          #fi
          if [ "${_pkgArg}" == "pkglist" ] ; then
              printf "%s: No RPMs / GROUPs for mandatory pkglist parameter!!!\n" $_func
              return 1
          else
              printf "%s: No RPMs / GROUPs for package list; skipping...\n" $_func
              continue
          fi
      fi

      # This may be a problem if each group is a space separated word...
      if [ ! -z "$_grpList" -a "$_grpList" != "" ] ; then
          _grpArgs=(groupinstall "${_cmdArgs[*]}" "$_grpList")
          printf "%s: %s %s\n" $_func "$_cmd" "${_grpArgs[*]}"
          $_cmd ${_grpArgs[@]}
          if [ $? -ne 0 ] ; then
              printf "%s: ERROR yum groupinstall #%d FAILED!\n" $_func ${_listCount}
              return 1
          fi
      fi

      if [ ! -z "$_rpmList" -a "$_rpmList" != "" ] ; then
          _rpmArgs=(install "${_cmdArgs[@]}" $_rpmList)
          printf "%s: #%d %s %s\n" $_func ${_listCount} "$_cmd" "${_rpmArgs[*]}"
          $_cmd ${_rpmArgs[@]}
          if [ $? -ne 0 ] ; then
              printf "%s: ERROR yum install #%d FAILED!\n" $_func ${_listCount}
              return 1
          fi
      fi

      # delete whatever is specified from the rpm download area
      if [ ${_listCount} -eq 1 ] ; then
          for _pat in $_delExtra ; do
              printf "%s: remove %s\n" $_func "${_rpmDloadPath}/${_pat}*.rpm"
              rm -f ${_rpmDloadPath}/${_pat}*.rpm
          done
      fi

      if [ ! -z "$_copyList" ] ; then
          for _file in $_copyList; do
              printf "%s: copy #%d %s -> %s\n" $_func ${_listCount} "$_file" "$_rpmDloadPath"
              cp "$_file" "$_rpmDloadPath"
              if [ $? -ne 0 ] ; then
                  printf "%s: RPMLIST copy failed\n" $_func
                  return 1
              fi
          done
      fi

      # Check for first matching rpms to use for ISO name.  This does not change
      # ${_args[iso-out]} only $ISO_CREATE_FILE_PATH!!!
      if [ ! -z "$_rpmList" ] && [ ! -z "$_iso_pattern" ]; then
          if [[ "$_rpmList" =~ [[:space:]]*($_iso_pattern.*?)[[:space:]]* ]] ; then
               if [ ! -z "${BASH_REMATCH[1]}" ] ; then
                    _iso_match=${BASH_REMATCH[1]}
                    echo "Extracted $_iso_match"
                    _iso_match=`basename $_iso_match`
                    _iso_match=${_iso_match%.rpm}
                    _iso_match=$_iso_match'.iso'
                    _iso_path=`dirname $ISO_CREATE_FILE_PATH`
                    ISO_CREATE_FILE_PATH=$_iso_path"/"$_iso_match
                    echo "ISO_CREATE_FILE_PATH:=$ISO_CREATE_FILE_PATH"
               fi
          fi
      fi

      _listCount=$((_listCount+1))
  done

  # so lame, but sudo yum install changes the ownership of the root install dir
  # to root so we change it back so that the safe path check doesn't fail the
  # next time the script is run...
  if [ ! -z "$_origInstRootOwner" ] ; then
       printf "%s: Restoring %s as %s owner\n" $_func "$_origInstRootOwner" "$_instRootPath"
       printf "%s: sudo chown %s %s\n" $_func "$_origInstRootOwner" "$_instRootPath"
       sudo chown "$_origInstRootOwner" "$_instRootPath"
       if [ $? -ne 0 ] ; then
           printf "%s: Could not restore original owner for %s files\n" $_func "$_origInstRootOwner"
           return 1
       fi
  fi

  output_n_chars '-' 79
  return 0
}

#
# rpm_download:
#
# Explicitly download RPMs into the yum downoad staging area
#
# $1 - IN: Name of parameters assoc. array
# $2 - IN: install or no-install (if not provided defaults to no-install)
#
# Unforunately yumdownloader cannot use a temp cache or an installroot
# so we have to fudge it...
#
# Warning: If space-separated names are used for packages/groups, this may
#          present problems which wll madate rewriting how argument lists
#          are presented to yum...
#
function rpm_download {
    local _func=${FUNCNAME}

    local _argsName=$1
    local _astr=''
    local _args

    if [ -z "$_argsName" ] ; then
        printf "%s: Missing Parameter List Name\n"
        return 1
    fi

    _astr=$(declare -p $_argsName)
    eval "readonly -A _args="${_str#*=}

    local _instRootPath=${_args[yum_install_path]}
    local _rpmDloadPath=${_args[yum_rpm_path]}
    local _rpmFile=${_args[rpm-file]}
    local _instVer=${_args[os-version]}
    local _yumConfFile=${_args[yum-conf]}

    if [ -z "$_instRootPath" ] ; then
        printf "%s: ERROR RootInstallPath not provided!\n" $_func
        return 1
    fi
    if [ ! -d "$_instRootPath" ] ; then
        printf "%s: ERROR RootInstallPath %s not found!\n" $_func $_instRootPath
        return 1
    fi
    if [ -z "$_rpmDloadPath" ] ; then
        printf "%s: ERROR RPM Download Path not provided!\n" $_func
        return 1
    fi
    if [ ! -d "$_rpmDloadPath" ] ; then
        printf "%s: ERROR RPM Download Path %s not found!\n" $_func $_rpmDloadPath
        return 1
    fi

    if [ -z "$_doInstall" -o "$_do_install" == "" ] ; then
        _doInstall="no-install"
    fi
    if [ "$_doInstall" != "install" -a "$_doInstall" != "no-install" ] ; then
        printf "%s: ERROR Invalid Install directive - $_doInstall!\n" $_func
        return 1
    fi

    printf "%s(%s, %s, '%s', %s, %s)\n" $_func $_instRootPath $_rpmDloadPath \
        "$_instList" $_instVer $_doInstall

    # initialize install root to use repo config
    copy_repo_config _args
    if [ $? -ne 0 ] ; then
        printf "%s: copy_repo_config FAILED!\n" $_func
        return 1
    fi

    local _rpmList=''
    local _rpm=''
    local _rpmArgs=''
    local _xtraArgs=''
    local _line=''
    local _ftype

    if [ ! -f "$_rpmFile" ] ; then
        show_error "%s: ERROR cannot find %s\n" $_func $_rpmFile
        return 1
    fi
    # a binary file makes a nice mess...
    _ftype=$(file -i "$_rpmFile")
    if [[ "$_ftype" =~ charset=([^;[:space:]]+) ]] ; then
        _ftype=${BASH_REMATCH[1]//*-/}
        if [ "$_ftype" != "ascii" ] ; then
            show_error "%s: Bad type=%s for %s\n" $_func "$_ftype" "$_rpmFile"
            return 1
        fi
    fi

    if [ "$_doInstall" != "install" ] ; then
        add_to_list _xtraArgs "--downloadonly"
    else
        add_to_list _xtraArgs "-y"
    fi
    if [ ! -z "$_instVer" ] ; then
        if [[ $_instVer =~ [0-9]+ ]] ; then
            printf "%s: add_to_list _xtraArgs --releasever=%s\n" $_func $_instVer
            add_to_list _xtraArgs "--releasever=$_instVer"
        else
            printf "%s: Release Version \'%s\' Must be Numeric\n" $_func $_instVer
            return 1
        fi
    fi
    if [ ! -z "$_yumConfFile" ] ; then
        printf "%s: add_to_list _xtraArgs --config=\n" $_func $_yumConfFile
        add_to_list _xtraArgs "--config=$_yumConfFile"
    fi

    local _cmd="sudo yum"
    local _cmdArgs=("--installroot=$_instRootPath" "--downloaddir=$_rpmDloadPath" "$_xtraArgs")
    local _cnt=0
    local _rpmCnt=0

    local _file
    local _pos
    local _rpm_pats
    declare -A _rpm_pats

    # strip .rpm extension if it is present...
    while read _line ; do
        _line=${_line//*([[:space:]])/}
        _pos=${#_line}
        _pos=$((_pos-4))
        if [ ${_line:$_pos:4} == ".rpm" ] ; then
            _line=${_line:0:$_pos}
        fi
        if [ -z "$_rpmList" ] ; then
            _rpmList="$_line"
        else
            _rpmList="$_rpmList $_line"
        fi
        _rpmCnt=$((_rpmCnt+1))

        printf "%s(%s): added %s\n" $_func $_rpmCnt "$_line"
        _rpm_pats["$_line"]="match"
    done < "$_rpmFile"

    if [  -z "${_args[rpm2iso-singly]}" ] ; then
         _rpmArgs=(install "${_cmdArgs[@]}" $_rpmList)
         printf "%s: %s %s\n" $_func "$_cmd" "${_rpmArgs[*]}"
         $_cmd ${_rpmArgs[@]}
         if [ $? -ne 0 ] ; then
             printf "%s: ERROR yum install FAILED!\n" $_func
             return 1
         fi
    else
        # do one rpm at a time for now..... slow!!!!
        for _rpm in $_rpmList ; do
            _rpmArgs=(install "${_cmdArgs[@]}" $_rpm)
            _cnt=$((_cnt+1))
            printf "%s(%s/%s): %s %s\n" $_func $_cnt $_rpmCnt "$_cmd" "${_rpmArgs[*]}"
            $_cmd ${_rpmArgs[@]}
            if [ $? -ne 0 ] ; then
                printf "%s: ERROR yum install FAILED!\n" $_func
                return 1
            fi
        done
    fi

    # check for extra files
    for _file in `ls $_rpmDloadPath` ; do
        _file=`basename $_file`
        _pos=${#_file}
        _pos=$((_pos-4))
        _file=${_file:0:$_pos}

        if [ -z "${_rpm_pats[$_file]}" ] ; then
            printf "%s: Extra RPM file: %s\sn" $_func "$_file"
        fi
    done

    # check for missing files
    local _arpms=($_rpmList)
    for _rpm in "${_arpms[@]}" ; do
        echo "checking $_rpm"
        if [ ! -f "$_rpmDloadPath/$_rpm.rpm" ] ; then
            show_error "%s: Missing RPM file: %s. Consider checking yum configuration (/etc/yum.repos.d)\n" \
                       $_func "$_rpm"
            return 1
        fi
    done

    return 0
}

#
# populate_kickstart:
#
# Populates the provided kickstart file with the packages specified
# 'Normally' these should be the packages (or package goups) used to
# seed the ISO.
#
# $1 -  IN:  Argument Associative Array
# $2 -  IN:  Parameter Name to use for package list
#            defaults to 'pkglist' if not provided 
#
# WARNING: Groups RPMs prefaced with "'" will be added exactly as
#          such to the kickstart file
#
#
function populate_kickstart {
  local _pkg_regex_begin='%packages'
  local _pkg_regex_end='%end'
  local _func=${FUNCNAME}

  local _infile
  local _instList
  local _outfile
  local _tmpfile
  local _var
  local _argVals
  local _argValsName=$1
  local _paramName=$2

  if [ -z "$_argValsName" ] ; then
      printf "%s: Argument aray not provided\n" $_func
      return 1
  fi

  if [ -z "${_paramName}" ] || \
     [ "${_paramName}" == "" ] ; then
      _paramName='pkglist'
  fi

  printf "%s: Using '%s' as Parameter Name\n" ${_func} ${_paramName}

  _var=$(declare -p $_argValsName)
  eval "readonly -A _argVals="${_var#*=}

  _infile=${_argVals['ks-file']}
  _outfile=`basename $_infile`
  _outfile=$ISO_STAGING_PATH'/'$_outfile

  if [ -z "$_infile" ] ; then
      printf "%s: ERROR infile not provided!\n" $_func
      return 1
  fi
  if [ ! -f "$_infile" ] ; then
      printf "%s: ERROR infile=$_infile not found!\n" $_func
      return 1
  fi
  if [ -z "$_outfile" ] ; then
      printf "%s: ERROR outfile not provided!\n" $_func
      return 1
  fi
  if [ -f "$_outfile" ] ; then
      printf "%s: WARNING replacing $_outfile!\n" $_func
      rm -f $_outfile
      if [ $? -ne 0 ] ; then
          printf "%s: FAILED replacing $_outfile!\n" $_func
          return 1
      fi
  fi

  _instList=${_argVals[$_paramName]}
  if [ -z "$_instList" ] ; then
      printf "%s: ERROR install list!\n" $_func
      return 1
  fi
  # Append pkglast so these packages get intalled too...
  if [ ! -z "${_argVals['pkglast']}" ] ; then
      _instList=${_instList}" "${_argVals['pkglast']}
  fi

  local _rpm
  local _pkg
  local _line
  local _pkgList
  local _in_section

  move_groups_to_front _instList
  if [ $? -ne 0 ] ; then
      printf "%s: move_groups_to_front FAILED\n" $_func
      return 1
  fi

  _tmpfile=`mktemp`
  if [ $? -ne 0 ] ; then
      printf "%s: create temp file failed!\n" $_func
      return 1
  fi

  for _pkg in  $_instList ; do
      if [ $_pkg == '' -o ${#_pkg} -le 2 ] ; then
          continue
      fi
      # Do not add this to the kickstart file...
      if [ "${_pkg:0:1}" == "-" ] ; then
          printf "%s: omit $_pkg from kickstart\n" $_func
          continue
      fi
      if [ "${_pkg:0:1}" == "+" -o "${_pkg:0:1}" == "~" ] ; then
          _rpm=${_pkg:1}
          _rpm=`basename $_rpm`
          _rpm=${_rpm//-[0-9]*/}
          add_to_list _pkgList $_rpm
      else
          add_to_list _pkgList $_pkg
      fi
  done

  printf "%s: pkglist=\'%s\'\n" $_func "${_pkgList[@]}"

  _in_section=1
  while read _line ; do
      if [[ $_line =~ "$_pkg_regex_begin" ]]  ; then
          printf "%s\n" $_pkg_regex_begin >> $_tmpfile
          _in_section=0
      fi
      if [ $_in_section == 0 ] &&
        [[ $_line =~ "$_pkg_regex_end" ]]  ; then
          _in_section=1
          for _pkg in $_pkgList ; do
               printf "%s\n" $_pkg >> $_tmpfile
          done
      fi
      if [ $_in_section == 1 ] ; then
          printf "%s\n" "$_line" >> $_tmpfile
      fi
  done < $_infile

  local _status
  populate_template_file $_tmpfile $_argValsName $_outfile
  _status=$?
  if [ $_status -ne 0 ] ; then
      printf "%s: Failed to templatize %s\n" $_func $_tmpfile
      _status=1
  fi

  rm -f $_tpmfile
  return $_status
}

#
# populate_template_file
#
# Populates a grub file to be compatible with the ISO being created
#
# $1  IN: Path of template file used to generate ISO grub.cfg
# $2  IN: Name of an ass. array of variables to replace if found in template file
# $3 OUT: Path to ISO staging
#
#
function populate_template_file {
  local _infile=$1
  local _outfile=$3
  local _var
  local _vals
  local _key
  local _xkey

  local _func=${FUNCNAME}

  if [ -z "$_infile" ] ; then
      printf "%s: ERROR infile not provided!\n" $_func
      return 1
  fi
  if [ ! -f "$_infile" ] ; then
      printf "%s: ERROR inile=$_infile not found!\n" $_func
      return 1
  fi
  if [ -z "$_outfile" ] ; then
      printf "%s: ERROR outfile not provided!\n" $_func
      return 1
  fi
  if [ -f "$_outfile" ] ; then
      printf "%s: WARNING replacing $_outfile!\n" $_func
      rm -f $_outfile
      if [ $? -ne 0 ] ; then
          printf "%s: FAILED replacing $_outfile!\n" $_func
          return 1
      fi
  fi
  if [ -z "$2" ] ; then
      printf "%s: ERROR values not provided!\n" $_func
      return 1
  fi

  printf "%s: %s -> %s\n" $_func $_infile $_outfile

  _var=$(declare -p "$2")
  eval "readonly -A _vals="${_var#*=}

  # for each line, try all variable replacements per $2 ass. array
  while read _line ; do
     for _key in ${!_vals[@]} ; do
         # e.g. allow a match of _argVals[iso.boot_timout] to {{ ISO_BOOT_TIMEOUT }} in file
         if [ "${_key:0:3}" != 'iso' ] ; then
             continue
         fi
         _xkey=${_key^^}
         _xkey=${_xkey/./_}
         _line=${_line//\{\{*([[:space:]])"$_xkey"*([[:space:]])\}\}/${_vals[$_key]}}
     done
     printf "TMPL: %s\n" "$_line"
     printf "%s\n" "$_line" >> $_outfile
  done < $_infile

  # Check to see if anything is left that looks like a unpopulated
  # template variable, and fail if found...
  local _return_code=$STATUS_OK
  local _line_count=1
  while read _line ; do
      if [[ $_line =~ {{[[:space:]]*[^[[:space:]]]+[[:space:]]*}} ]] ; then
           printf "${TERMINAL_COLOR_RED}%s${TERMINAL_STYLE_NORMAL}\n" "TMPL WARN\[$_line_count\]: $_line"
           _return_code=$STATUS_FAIL
      fi
      _line_count=$((_line_count+1))
  done < $_infile

  return $_return_code
}

#
# copy_files
#
# Populates a grub file to be compatible with the ISO being created
#
# $1 - argument array to process...
# $2 - file data type argument
#
function copy_files {
    local _filedata
    local _info
    local _src
    local _srcpath
    local _dst
    local _dstpath
    local _entries
    local _is_dir_dest=1
    local _testpath=''

    local _func=${FUNCNAME}
    local _argValsName=$1
    local _argType=$2

    printf "%s: 1=%s 2=%s\n" $_func $_argValsName $_argType

    if [ -z "$_argType" ] ; then
        printf "%s: No argType provided\n" $_func
        return 1
    fi
    if [ -z "$_argValsName" ] ; then
        printf "%s: No argVals provided\n" $_func
        return 1
    fi

    _var=$(declare -p "$_argValsName")
    eval "readonly -A _argVals="${_var#*=}
    _filedata=(${_argVals[$_argType]})

    printf "%s: _argVals[%s]=%s\n" $_func $_argType "${_filedata[*]}"

    for _info in ${_filedata[@]} ; do
        _is_dir_dest=1
        _entries=(${_info//,/ })
        _src=${_entries[0]}
        _dst=${_entries[1]}

        if [ -z "$_src" ] ; then
            printf "%s: No source file provided\n" $func
            return 1
        fi
        printf "%s: %s %s\n" "$_func" src="$_src" dst="$_dst"

        # If source path is not absolute, prepend default absolute path
        _srcpath=$_src
        if [ ${_src:0:1} != '/' ] ; then
            _srcpath=$MKISO_CONFIG_PATH'/'$_src
        fi
        # Source file must exist!
        if [ ! -e $_srcpath ] ; then
            printf "%s: source file %s does not exist; check copy-sources\n" $_func $_srcpath
	    # Check the copy-source parameters for alternate locations 
	    _findcount=0
	    _multi_list=""
	    _pathlist=(${_argVals['copy-source']})
	    for _path in ${_pathlist[@]} ; do
		_srcpath=${MKISO_INVOKED_PATH}
		if [ ${_src:0:1} != '/' ] ; then
		    _srcpath=${_srcpath}"/"
                fi
		_srcpath=${_srcpath}${_path}
		if [ ${_src:0:1} != '/' ] ; then
		    _srcpath=${_srcpath}"/"
                fi
		_srcpath=${_srcpath}${_src}
		printf "%s: checking source %s...\n" ${_func} ${_srcpath}
		if [ -e ${_srcpath} ] ; then
		    _findcount=$((_findcount+1))
		    printf "%s: found source %d %s...\n" ${_func} ${_findcount} ${_srcpath}
		    if [ "${_multi_list}" == "" ] ; then
			_multi_list=${_srcpath}
		    else
			_multi_list="${_multi_list}, ${_srcpath}"
		    fi
		fi
            done
	    if [ ${_findcount} -eq 0 ] ; then
		show_error "%s: copy source file '%s' not found\n" $_func $_src
		printf "%s: copy source file '%s' not found\n" $_func $_src
		return 1
	    fi
	    if [ ${_findcount} -gt 1 ] ; then
		show_error "%s: multiple source files '%s' \n" $_func "${_multi_list}"
		printf "%s: multiple source files '%s' \n" $_func "${_multi_list}"
		return 1
	    fi
        fi
        # Source file must exist!
        if [ -d $_srcpath ] ; then
            show_error "%s: source file %s is a directory!\n" $_func $_srcpath
            printf "%s: source file %s is a directory!\n" $_func $_srcpath
            return 1
        fi
        # Defaults the destination path to the src path if not provided
        if [ -z "$_dst" ] ; then
            _dst=`dirname $_src`
            # create the destination if need be...
            if [ ! -z "$_dst" ] ; then
                _is_dir_dest=0
            fi
        fi
        if [ "${_dst}" == '.' ] ; then
            _dst=''      
        fi
        printf "_dst=%s\n" $_dst
        # if dest path not absolute, prepend default absolute path
        _dstpath=$_dst
        printf "dst_path1=%s\n" $_dstpath
        if [ "${_dst}" == "" ] ; then
            _dstpath=$ISO_STAGING_PATH
	elif [ ${_dst:0:1} != '/' ] ; then
            _dstpath=$ISO_STAGING_PATH'/'$_dst
        fi
        printf "dst_path2=%s\n" $_dstpath
        if [[ ! $_dstpath =~ ^$ISO_STAGING_PATH ]] ; then
            printf "%s: Destination directory %s must be in staging area!!!!!\n" \
                $_func "$_dstpath"
            return 1
        fi
        # is the dest a directory?
        printf "dst_path3=%s\n" $_dstpath
        if [ ${_dstpath:-1} == '/' ] ; then
            _dstpath=${_dstpath%?}
            _is_dir_dest=0
        fi
        # '.' alone is not sufficient
        _dstdir=`dirname $_dstpath`
        if [  "$_dstdir" == '.' ] ; then
            printf "%s: Destination cannot be '.'\n" $_func "$_dstdir"
            return 1
        fi
        printf "dst_path4=%s\n" $_dstpath
        # The dest directory path must exist
        _testpath=$_dstpath
        if [ $_is_dir_dest -ne 0 ] ; then
            _testpath=`dirname $_dstpath`
        fi
        printf "dst_path5=%s\n" "$_testpath"
        if [ ! -d "$_testpath" ] ; then
            if [  $_is_dir_dest -eq 0 ] ; then
                mkdir -p "$_testpath"
                if [ $? -ne 0 ] ; then
                    printf "%s: mkdir Destination %s FAILED\n" $_func $_testpath
                    return 1
                fi
            else
                printf "%s: Destination directory %s Missing\n" $_func $_testpath
                return 1
            fi
        fi
        # If the pathname is a directory, grab the filename from the source
        if [ $_is_dir_dest -eq 0 ] ; then
            _dst=`basename $_src`
            _dstpath="$_dstpath"/"$_dst"
        fi
        if [ $_argType == 'template' ] ; then
             printf "%s: %s(%s %s %s)\n" $_func 'populate_template_file' \
                    $_srcpath $_argValsName $_dstpath
             populate_template_file $_srcpath $_argValsName $_dstpath
             if [ $? -ne 0 ] ; then
                 printf "%s: propulate_template_file FAILED!!!!\n" $_func
                 return 1
             fi
         else
            printf "%s: cp %s -> %s\n" $_func $_srcpath $_dstpath
            cp $_srcpath $_dstpath
            if [ $? -ne 0 ] ; then
                 printf "%s: copy FAILED!!!!\n" $_func
                 return 1
            fi
        fi
    done
}


#
# copy_urls
#
# Populates $ISO_STAGING_PATH/downloads with the URLS specified using the
# misc-url directive.
#
# Note that there is no way for mkiso to know why these files are needed.  In
# some cases it may be necessary to copy the downloaded files from the ISO
# mounted downloads path to somewhere on the rootfs of the OS being
# installed.  In this case, kickstart commands can be used to correcly place
# the file from the ISO.
#
# $1 - argument array to process...
#
function copy_urls {
    local _filedata
    local _src

    local _func=${FUNCNAME}
    local _argValsName=$1

    if [ -z "$_argValsName" ] ; then
        printf "%s: No argVals provided\n" $_func
        return 1
    fi

    _var=$(declare -p "$_argValsName")
    eval "readonly -A _argVals="${_var#*=}
    _filedata=(${_argVals[misc-url]})

    local _dloadpath="$ISO_STAGING_PATH/downloads"
    local _curdir
    local _status=0

    for _src in ${_filedata[@]} ; do
        if [ ! -d "$_dloadpath" ] ; then
            mkdir -p "$_dloadpath"
            if [ $? -ne 0 ] ; then
                printf "%s: Unable to create staging area path -- $_dloadpath"
                return 1
            fi
        fi
        _curdir=`pwd`
        cd $_dloadpath
        curl --remote-name $_src
        _status=$?
        cd $_curdir
        if [ $_status -ne 0 ] ; then
             printf "%s: Failed to acquire -- %s\n" $_func $_src
             return 1
        fi
        printf "%s: %s -> %s\n" $_func $_src $_dloadpath
    done

    return 0
}


#
# enable_uefi_boot:
#
#
#
function enable_uefi_boot {
   local _iso_staging_path=$1
   local _efi_staging_path=$2

   local _func=${FUNCNAME}

   local _srcpath
   local _efi_image
   local _srcfile=EFI/BOOT/grub.cfg
   local _dstdir=EFI/BOOT

   if [ -z "$_efi_staging_path" ] ; then
       printf "%s: ERROR empty uefi staging path\n" $_func
       return 1
   fi
   if [ -z "$_iso_staging_path" ] ; then
       printf "%s: ERROR empty iso staging path\n" $_func
       return 1
   fi
   if [ ! -d "$_iso_staging_path" ] ; then
       printf "%s: ERROR missing uefi staging %s\n" $_func $_iso_staging_path
       return 1
   fi

   if [ ! -d $_efi_staging_path ] ; then
       mkdir -p $_efi_staging_path
       if [  $? -ne 0 ] ; then
           printf "%s: ERROR mkdir FAILED uefi-staging %s\n" $_func $_efi_staging_path
           return 1
       fi
   fi

   if [ ! -d "$_efi_staging_path" ] ; then
       printf "%s: ERROR missing uefi staging %s\n" $_func $_efi_staging_path
       return 1
   fi

   _srcpath=$_iso_staging_path'/'$_srcfile
   if [ ! -f $_srcpath ] ; then
       printf "%s: ERROR _srcfile=%s/%s Missing!!!\n" $_func $_srcpath
       return 1
   fi

   _efi_image=$_iso_staging_path'/images/efiboot.img'
   if [ ! -e "$_efi_image" ] ; then
       printf "%s: ERROR efi_image=%s Missing!!!\n" $_func $_efi_image
       return 1
   fi

   # This mount has to be writeable
   printf "%s: mount %s -> %s\n" $_func $_efi_image $_efi_staging_path
   sudo mount -o loop $_efi_image $_efi_staging_path
   if [ $? -ne 0 ] ; then
       printf "%s: ERROR mounting %s\n" $_func $_efi_image
       return 1
   fi

   # $_dstpath is not valid until the image is mounted
   _dstpath=$_efi_staging_path'/'$_dstdir
   if [ ! -d $_dstpath ] ; then
       printf "%s: ERROR dstpath=%s Missing!!!\n" $_func $_dstpath
       sudo umount $_efi_staging_path
       if [ $? -ne 0 ] ; then
           printf "%s: ERROR unmounting efiboot.img\n" $_func
           return 1
       fi
       return 1
   fi

   printf "%s: %s -> %s\n" $_func $_srcpath $_dstpath
   sudo cp $_srcpath $_dstpath
   if [ $? -ne 0 ] ; then
       sudo umount $_efi_staging_path
       printf "%s: ERROR copying grub.cfg\n" $_func
       return 1
   fi

   printf "%s: umount %s\n" $_func $_efi_staging_path
   sudo umount $_efi_staging_path
   if [ $? -ne 0 ] ; then
       printf "%s: ERROR unmounting efiboot.img\n" $_func
       return 1
   fi

   return 0
}

#
# copy_iso
#
# $1: IN  - input ISO file
# $2: IN  - mount point
# $3: OUT - destination path
# $4: IN  - additional rync args (i.e. --exclude Packaging)
#
function copy_iso {
    local _isofile=$1
    local _mntdir=$2
    local _copypath=$3
    local _func=${FUNCNAME}
    local _ftype=''
    local _status=0
    local _rsync_status=0

    if [ -z "$_isofile" -o ! -f "$_isofile" ] ; then
        printf "%s: ERROR missing iso input $_isofile\n" $_func $_isofile
        return 1
    fi

    # make sure its an ISO image...
    _ftype=$(file -i "$_isofile")
    if [[ "$_ftype" =~ application/([^;[:space:]]+) ]] ; then
        _ftype="${BASH_REMATCH[1]}"
        if [ "$_ftype" != 'x-iso9660-image' ] ; then
            show_error "%s: Bad type=%s for input ISO\n" $_func "$_ftype"
            return 1
        fi
    fi

    if [ -z "$_mntdir" ] ; then
        printf "%s: ERROR mntdir %s empty\n" $_func $_mntdir
        return 1
    fi
    if [ -z "$_copypath" ] ; then
        printf "%s: ERROR copypath %s empty\n" $_func $_copypath
        return 1
    fi

    printf "%s (%s, %s, %s)\n" $_func "$1" "$2" "$3"

    if [ ! -d $_mntdir ] ; then
         mkdir -p $_mntdir
        _status=$?
        if [ $_status != 0 ] ; then
            printf "%s: ERROR mkdir mntdir=%s failed\n" $_func $_mntdir
            return 1
        fi
    fi

    if [ ! -d $_copypath ] ; then
        printf "%s: mkdir -p %s\n" $_func $_copypath
        mkdir -p $_copypath
        _status=$?
        if [ $_status -ne  0 ] ; then
            printf "%s: ERROR mkdir copypath=%s failed\n" $_func $_copypath
            return 1
        fi
    fi

    # Remove any data leftover from prior ISO creation...
    if [ -d "$_copypath" ] ; then
        check_path_safe "$_copypath" $_func
        if [ $? -ne 0 ] ; then
            return 1
        fi
        # Use extglob to remove everything other than repodata, and then
        # everything in repodata other than comps.xml
        printf "%s: Remove pkgpath %s\n" $_func "$_copypath/$ISO_PACKAGES_DIR"
        rm -rf $_copypath/!(repodata)
        rm -f $_copypath/repodata/!(*comps*.xml)
    fi

    local _mount_cmd="sudo mount"
    local _mount_args=(-o loop "$_isofile" "$_mntdir")
    local _umount_cmd="sudo umount"
    local _umount_args="$_mntdir"
    local _rsync_cmd="rsync"
    local _rsync_args="-avz --exclude TRANS.TBL"
    local _msg=''

    if [ ! -z "$4" ] ; then
         _rsync_args=$_rsync_args" $4"
    fi
    _rsync_args="$_rsync_args $_mntdir/* $_copypath"

    echo $_mount_cmd ${_mount_args[@]}
    $_mount_cmd "${_mount_args[@]}"
    _status=$?
    if [ $_status != 0 ] ; then
        return $_status
    fi

    # ### To use pv to provide a progress bar... (disabled for now)
    # ### add pv to the list of required packages...
    # _rargs=($_rsync_args)
    # _data=$($_rsync_cmd --dry-run --stats ${_rargs[*]} | head -2)
    # _filecnt="${_data//[^0-9]/}"
    # ### and further below:
    # $_rsync_cmd="-v $_rsync_args | pv -lep -s $_filecnt"

    output_n_chars '-' 79
    echo $_rsync_cmd $_rsync_args
    echo ""
    _msg="This transfer may take some time escpecially if a SAMBA source is used..."
    printf "${TERMINAL_COLOR_BLUE}%s${TERMINAL_STYLE_NORMAL}\n" "${_msg}"
    output_n_chars '-' 79

    $_rsync_cmd $_rsync_args
    _rsync_status=$?
    if [ $_rsync_status != 0 ] ; then
        printf "%s: ERROR rsync %s to %s failed\n" $_func $_mntdir $_copypath
    fi

    echo $_umount_cmd $_umount_args
    $_umount_cmd $_umount_args
    _status=$?
    if [ $_status != 0 ] ; then
        printf "%s: ERROR umount %s failed\n" $_func $_mntdir
        return 1
    fi

    return $_rsync_status
}

#
# move_rpms_to_staging:
#
# $1 - IN:  Yum RPM Path
# $2 - OUT: ISO Staging path
# $3 - IN: copyOnMove (1 -> do not copy; 0 => copy rpms)
# $4 - IN: group file location? (TODO)
##
# TODO: When creating a new repo, consider allowing a groups file to be specified
#       furthermore consider defining a new group to install all rpms from the
#       output of a 128T's 'rpm -qa'
#
function move_rpms_to_staging {
   local _curdir=`pwd`
   local _kerpath=''
   local _func=${FUNCNAME}

   local _rpm_path=$1
   local _iso_staging=$2
   local _copy_not_move=$3

   if [ -z "$_copy_not_move" ] ; then
        _copy_not_move=1
   fi

   if [ -z "$_rpm_path" -o ! -d "$_rpm_path" ] ; then
       _path=''
       if [ ! -z "$_rpm_path" ] ; then
           _path=$_rpm_path
       fi
       printf "%s: ERROR RPM path %s missing\n" $_func $_path
       return 1
   fi

   if [ -z "$_iso_staging" -o ! -d "$_iso_staging" ] ; then
       _path=''
       if [ ! -z "$_iso_staging" ] ; then
           _path=$_iso_staging
       fi
       printf "%s: ERROR ISO path %s missing\n" $_func $_path
       return 1
   fi

   printf "%s(rpmdir=%s, stagedir=%s, copy=%d)\n" $_func $1 $2 $3

   local _path
   local _file
   local _kernel_rpm_name
   local _leaf_dir
   local _package_by_char
   local _char1
   local _target_dir
   local _gfiles=()
   local _grouparg
   local _repoargs
   local _repocnt
   local _repobase

   # any error returns after this comment are expected
   # to restore the original current directory
   cd $_iso_staging
   if [ -d $ISO_PACKAGES_DIR ] ; then
       echo "Target Package Dir Exists (%s)... "
       _kernel_rpm_path=`find . -name "kernel-[0-9]*" -print`
       if [ -z "$_kernel_rpm_path" ] ; then
           printf "%s: ERROR cannot find rpms @ %s\n" $_func $_iso_staging'/'$ISO_PACKAGES_DIR
           return 1
       fi
       _target_dir=`dirname $_kernel_rpm_path`
       _file=`basename $_kernel_rpm_path`
       _leaf_dir=`basename $_target_dir`
       _char1=${_file:0:1}
       if [ $_char1 == $_leaf_dir ] ; then
           _package_by_char=0
           _target_dir=`dirname $_target_dir`
       else
           _package_by_char=1
       fi
       echo -n "Single Char Dir: "
       if [ $_package_by_char -eq 0 ] ; then
            echo "Yes"
       else
            echo "No"
       fi
       echo "Target Path:     $_target_dir"
       for _path in  `find $_rpm_path -name '*.rpm' -print` ; do
           _file=`basename $_path`
           if [ $_package_by_char -eq 0 ] ; then
               _char1=${_file:0:1}
               _target_dir=$_target_dir'/'$_char1
           fi
           if [ ! -d $_target_dir ] ; then
               mkdir -p $_target_dir
           fi
           printf "%s[%s]: %s -> %s\n" $_func `pwd` $_path $_target_dir
           if [ $_copy_not_move -ne 0 ] ; then
               mv $_path $_target_dir
           else
               cp $_path $_target_dir
           fi
       done
       _repobase=$_target_dir
       # update the repo database, and group (comps.xml) files...
       _repocnt=0
       for _path in `find $_iso_staging -type d -name 'repodata' -print` ; do
           _gfiles=()
           _grouparg=''
           _target_dir=`dirname $_path`
            printf "%s: Update repodata for %s\n" $_func $_target_dir
           _gfiles=(`ls $_path/*comps*.xml`)
           if [ ${#_gfiles[@]} -gt 1 ] ; then
               printf "%s: ERROR More than 1 comps.xml (%d) file in %s!!!\n" $_func  ${#_gfiles[@]} $_path
               for _file in ${_gfiles[@]} ; do
                   printf "...%s\n" $_file
               done
               cd $_curdir
               return 1
           fi
           if [ ${#_gfiles[@]} -eq 1 ] ; then
               _grouparg="--groupfile ${_gfiles[0]}"
           fi
           _repoargs="-v $_grouparg --update $_target_dir"
           echo createrepo  $_repoargs
           createrepo $_repoargs
           if [ $? -ne 0 ] ; then
               printf "%s: ERROR creating repo!!!\n" $_func
               cd $_curdir
               return 1
           fi
           _repocnt=$((_repocnt+1))
       done
       if [ $_repocnt -eq 0 ] ; then
           printf "%s: Create repodata for %s\n" $_func $_target_dir
           _repoargs="-v --create $_repobase"
           echo createrepo  $_repoargs
           createrepo $_repoargs
           if [ $? -ne 0 ] ; then
               printf "%s: ERROR creating repo!!!\n" $_func
               cd $_curdir
               return 1
           fi
       fi
   else
       printf "Target Package Dir DOES NOT Exist...\n"
       check_path_safe $_iso_staging $_func
       if [ $? -ne 0 ] ; then
           return 1
       fi
       # Using extglob, leave the comps file behind if it exists
       rm -rf $_iso_staging/repodata/!(*comps*.xml)
       _gfiles=(`ls $_iso_staging/repodata/*comps*.xml`)
       if [ ${#_gfiles[@]} -gt 1 ] ; then
           printf "%s: ERROR More than 1 comps.xml (%d) file in %s!!!\n" $_func ${#_gfiles[@]} $_path
           for _file in ${_gfiles[@]} ; do
               printf "...%s\n" $_file
           done
           cd $_curdir
           return 1
       fi
       if [ ${#_gfiles[@]} -eq 1 ] ; then
           _grouparg="--groupfile ${_gfiles[0]}"
       fi
       mv $_rpm_path $_iso_staging'/'$ISO_PACKAGES_DIR
       printf "%s: createrepo -v %s %s\n" $_func $_grouparg $_iso_staging
       createrepo $_grouparg -v .
       if [ $? -ne 0 ] ; then
           printf "%s: ERROR creating repodata!!!\n" $_func
           cd $_curdir
           return 1
       fi
   fi

   cd $_curdir
   return 0
}

#
# test_iso_install:
#
# $1  IN: Name of Arguments List
#
function test_iso_install {
    local _func=${FUNCNAME}
    local __argsName=$1

    if [ -z "$__argsName" ] ; then
        printf "%s: Missing Parameter List Name\n" $_func
        return 1
    fi

    local _astr
    local __args
    local _srchpath
    local _iso_path
    local _iso_mount
    local _line
    local _ksfile
    local _pkglist
    local _inPackages
    local _repos
    local _yum_conf_path
    local _do_app
    local _repopath
    local _repodef
    local _got_base

    # cannot be readonly as its overwritten below
    _astr=$(declare -p $__argsName)
    eval "declare -A __args="${_str#*=}

    _iso_path="${__args[iso-in]}"
    _iso_mount="${__args[iso_mount_path]}"

    sudo mount -r -o loop "$_iso_path" $_iso_mount
    if [ $? -ne 0 ] ; then
        printf "%s: mount %s FAILED!\n" $_func "$_iso_path"
        return 1
    fi

    printf "%s: ISO mounted!\n" $_func

    # grab the kickstart file from the boot menu in isolinux
    # directory of _iso_mount
    _srchpath="$_iso_mount/isolinux/isolinux.cfg"
    if [ ! -f $_srchpath ] ; then
        printf "%s: Missing srchpath=%s\n" $_func "$_srchpath"
        sudo umount "$_iso_mount"
        if [ $? -ne 0 ] ; then
            printf "%s: unmount %s FAILED!\n" $_func "$_iso_path"
        fi
        return 1
    fi

    _line=`grep ks= $_srchpath`
    printf "%s: KSLine='%s'\n" $_func "$_line"
    if [[ "$_line" =~ ks=hd:LABEL=[A-Za-z0-9/_\.-]+:/([A-Za-z0-9/_\.-]+)[[:space:]] ]] ; then
        _ksfile=${BASH_REMATCH[1]}
        _ksfile="$_iso_mount/$_ksfile"
    fi

    printf "%s: Kickstart file='%s'\n" $_func "$_ksfile"

    if [ -z "$_ksfile" ] ; then
        printf "%s: No kickstart file to scan\n" $_func
        sudo umount $_iso_mount
        if [ $? -ne 0 ] ; then
            printf "%s: unmount %s FAILED!\n" $_func "$_iso_path"
        fi
        return 1
    fi
    if [ ! -f $_ksfile ] ; then
        printf "%s: kickstart file '%s' not found!\n" $_func
        sudo umount $_iso_mount
        if [ $? -ne 0 ] ; then
            printf "%s: unmount %s FAILED!\n" $_func "$_iso_path"
        fi
        return 1
    fi

    # Need to extract package list from the kickstart file
    # might need to search the uefi boot info...
    _inPackages=1
    _got_base=1
    while read _line ; do
        if [[ $_line =~ [[:space:]]*# ]] ; then
            continue
        fi
        if [[ "$_line" =~ %packages ]] ; then
            _inPackages=0
            printf "%s: Found Package start %s\n" $_func $_ksfile
            continue
        fi
        if [ $_inPackages -eq 0 ] ; then
            if [[ "$_line" =~ %end ]] ; then
                printf "%s: Found Package end %s\n" $_func $_ksfile
                _inPackages=1
                continue
            fi
            _line=${_line//[[:space:]]/}
            if [ -z "$_pkglist" ] ; then
                _pkglist=$_line
            else
                _pkglist="$_pkglist $_line"
            fi
            printf "%s: Add to pkglist '%s'\n" $_func $_line
            if [[ "$_line" =~ base ]] ; then
                _got_base=0
            fi
        fi
    done < $_ksfile

    if [ $_got_base -eq 1 ] ; then
        _pkglist="$_pkglist @base"
    fi

    printf "%s: pkglist=%s\n" $_func "$_pkglist"

    # create yum conf/repo file based on iso repodata
    _repos=`find $_iso_mount -name "repodata" -type d -print`
    if [ -z "$_repos" ] ; then
        printf "%s: empty repolist\n" $_func
        sudo umount $_iso_mount
        if [ $? -ne 0 ] ; then
            printf "%s: unmount %s FAILED!\n" $_func "$_iso_path"
        fi
        return 1
    fi

    _yum_conf_path=`mktemp`

    declare -A array _repodef
    _repodef['YUM_REPO_ID']='ISO'
    _repodef['YUM_REPO_NAME']='ISO-Sourced Repo'
    _repodef['YUM_ENABLED']='1'
    _repodef['YUM_GPG_CHECK']='0'

    _doapp='no-append'
    for _repopath in $_repos ; do
        _repopath=`dirname $_repopath`
        if [ -z "$_repopath" ] ; then
            continue
        fi
        printf "%s: add repopath=%s\n" $_func $_repopath
        _repodef['YUM_BASE_URL']="file://$_repopath"
        echo "$_func: gen_yum_conf_from_array _repodef $_yum_conf_path $_doapp"
        gen_yum_conf_from_array _repodef $_yum_conf_path $_doapp
        if [ $? -ne 0  ] ; then
            printf "%s: gen_yum_conf_from_array FAILED!\n" $_func
            sudo umount $_iso_mount
            if [ $? -ne 0 ] ; then
                printf "%s: unmount %s FAILED!\n" $_func $_iso_path
            fi
            return 1
        fi
        _doapp='append'
    done

    printf "%s: ---------------- [Start Yum Conf] -------------------\n" $_func
    cat $_yum_conf_path
    printf "%s: ----------------  [End Yum Conf]  -------------------\n" $_func

    # user the temp file as the yum.conf source file; no repos or keys
    # need to be copied from the ISO (hopefully)
    __args['yum-conf']=$_yum_conf_path
    __args['yum_repo_src_conf']=$_yum_conf_path
    __args['yum_repo_src_path']=''
    __args['yum_pki_src_path']=''
    # disable the default repos yum creates and enable this one only... just in case
    # yum is as flaky as it seems...
    __args['yum_extra_args']="--disablerepo=* --enablerepo=${_repodef['YUM_REPO_ID']}"
    # replace any packages specified with the ones gleaned from the ISO's kickstart.
    __args['pkglist']="$_pkglist"
    __args['pkgdel']=''
    __args['pkglast']=''

    yum_download __args install
    _rv=$?

    rm -f $_yum_conf_path
    sudo umount $_iso_mount

    if [ $? -ne 0 ] ; then
        printf "%s: unmount %s FAILED\n" $_func $_iso_mount
        return 1
    fi

    return $_rv
}

#
# mkiso
#
# Creates an ISO image, and updates the checksum
#
# $1 - IN:   Path to directory of future ISO content
# $2 - OUT:  Path to future ISO file
# $3 - IN:   Volume  (can be empty if all aditional args are empty)
# $4 - IN:   Volume Set (can be empty if all aditional args are empty)
# $5 - IN:   Application ID (can be empty)
#
function mkiso {
   local _pathIn=$1
   local _pathOut=$2
   local _volIn=$3
   local _volSetIn=$4
   local _appId=$5

   _func=${FUNCNAME}
   _cmd='mkisofs'

   if [ -z "$_pathIn" ] ; then
      _pathIn=`pwd`
   fi
   if [ ! -d $_pathIn ] ; then
      printf "%s: ERROR source DIR %s not found!\n" $_func $_pathIn
      return 1
   fi

   if [ -z "$_pathOut" ] ; then
      printf "%s: ERROR ISO output path missing\n" $_func
      return 1
   fi

   if [ -z "$_appId" ] ; then
      _appId='mkiso'
   fi
   _appId=${_appId// /_}

   if [ -z "$_volIn" ] ; then
      _volIn='ISO'
   fi
   _volIn=${_volIn// /_}

   if [ -z "$_volSetIn" ] ; then
      _volSetIn='ISOSET'
   fi
   _volSetIn=${_volSetIn// /_}

   printf "%s: ISO Staging Path: %s\n" $_func $_pathIn
   printf "%s: ISO Target  Path: %s\n" $_func $_pathOut

   _isoArgs="-r -R -J -T -v -V $_volIn -volset $_volSetIn -A $_appId  -o $_pathOut -joliet-long \
-x \"lost+found\" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
-boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot . "

   cd $_pathIn
   echo $_cmd $_isoArgs
   $_cmd $_isoArgs

   if [ $? -ne 0 ] ; then
       printf "%s: mkisofs failed\n" $_func
       return 1
   fi

   cd ..

   isohybrid -u  $_pathOut
   if [ $? -ne 0 ] ; then
       printf "%s: isohybrid failed\n" $_func
       return 1
   fi

   implantisomd5 $_pathOut
   if [ $? -ne 0 ] ; then
       printf "%s: implantisomd5 failed\n" $_func
       return 1
   fi

   local _sumpath=${_pathOut}
   local _sumdir=`dirname ${_sumpath}`
   local _sumfile=`basename ${_sumpath}`
   local _status=0

   if [ -z "${_sumdir}" ] ; then
       printf "%s: Cannot Extract SUMS Directory" $_func
       return 1
   fi

   if [ -z "${_sumfile}" ] ; then
       printf "%s: Cannot Extract SUMS File" $_func
       return 1
   fi

   pushd ${_sumdir} &> /dev/null
   # For information purposes, this is the m5 sum which was inserted
   md5sum ${_sumfile} &> "${_sumpath}.md5"
   _status=$?
   if [ $_status -ne 0 ] ; then
       printf "%s: md5sum failed\n" $_func
   fi

   # For file integrity, this is the sha256sum of the ISO
   if [ $_status -eq 0 ] ; then
       sha256sum ${_sumfile} &> "${_sumpath}.sha256"
       _status=$?
       if [ $_status -ne 0 ] ; then
           printf "%s: sha256sum failed\n" $_func
       fi
   fi

   popd &> /dev/null
   return $_status
}

#
# print_help:
#
# $1 - IN: Command Help Array Name
# $2 - IN: Argumnt Hep Associative Array Name
#
function print_help {
   local _func=${FUNCNAME}
   local _cmdHelpName=$1
   local _argHelpName=$2

   local _key
   local _keys
   local _indent
   local _argHelp
   local _skey
   local _var

   if [ -z "$_argHelpName" ] ; then
       printf "%s: No help provided\n" $_func
       return 1
   fi

   if [ -z "$_cmdHelpName" ] ; then
       printf "%s: No help provided\n" $_func
       return 1
   fi

   # output the command-specific usage banner
   _var=$(declare -p $_cmdHelpName)
   eval "readonly -a _lArray="${_var#*=}

   eval "readonly -a $_cmdHelpName"
   for _line in "${_lArray[@]}" ; do
       _line="${_line//_/ }"
       printf "%s\n" "$_line"
   done

   # create the  current values array...
   _var=$(declare -p "$_argHelpName")
   eval "readonly -A _argHelp="${_var#*=}

   printf "\n"
   printf "Parameters:\n"
   echo "-----------"
   _keys=`echo "${!_argHelp[@]}" | tr ' ' '\n' | sort`
   for _key in $_keys ; do
       _skey="${_key}"
       _indent=15
       printf "%-${_indent}s : %s\n" $_skey "${_argHelp[$_key]}"
   done

   return 0
}

#
# print_cmd_help:
#
# $1 - IN: Name of commands associative array
#          entry format is <func-name>,<cmd-help-aray>
#
function print_cmd_help {
    local _entries
    local _entry
    local _func
    local _help
    local _lines
    local _line
    local _astr
    local _cmds

    local _aCmdName=$1

    if [ -z "$_aCmdName" ] ; then
        return 1
    fi

    _astr=$(declare -p $_aCmdName)
    eval "readonly -A _cmds="${_astr#*=}

    printf "\nUsage:\n"

    for _entry in "${_cmds[@]}" ; do
        _entries=(${_entry//,/ })
        _func=${_entries[0]}
        _help=${_entries[1]}
        _astr=$(declare -p $_help)
        eval "declare -a _lines="${_astr#*=}
        _crlfcnt=0
        for _line in "${_lines[@]}" ; do
            _line="${_line//_/ }"
            printf "%s\n" "$_line"
            if [ "$_line" == '' ] ; then
                _crlfcnt=$((_crlfcnt+1))
                # The second empty line in the command help arrays delimits
                # summary text from the full help text.
                if [ $_crlfcnt -eq ${MKISO_HELP_EMPTY_LINE_COUNT} ] ; then
                     break
                fi
            fi
        done
    done

    return 0
}

#
# process_show_args
#
# $1 - IN: Name of argument values ass. array.
# $2 - IN: Name of argument definitions ass. array.
# $3 - IN: Name of help ass. array
#
function process_show_args {
    local _func=${FUNCNAME}
    local _aStrName=$1
    local _aDefName=$2
    local _aHelpName=$3
    local _defs
    local _help
    local _astr
    local _cfgpath
    local _vstr

    if [ -z "$_aStrName" ] ; then
        printf "%s: Missing arg values array string\n" $_func
        return 1
    fi
    if [ -z "$_aDefName" ] ; then
        printf "%s: Missing arg defs array\n" $_func
        return 1
    fi
    if [ -z "$_aHelpName" ] ; then
        printf "%s: Missing arg help array\n" $_func
        return 1
    fi

    _astr=$(declare -p $_aDefName)
    eval "declare -A _defs="${_astr#*=}

    _astr=$(declare -p $_aHelpName)
    eval "declare -A _help="${_astr#*=}

    shift
    shift
    shift

    printf "%s: %s\n" $_func "$*"

    # ignore mandatory defaults...

    # grab the command line arguments...
    process_args 'cmdline' _defs $_aStrName $@

    eval "declare -A _vals="${!_aStrName}

    _cfgpath="${_vals[config]}"
    if [ -z "$_cfgpath" ] ; then
       _cfgpath='mkiso.cfg'
    fi
    if [ "${_cfgpath:0:1}" != "/" ] ; then
       tprint "$DEBUG_FLAG" "%s: _cfgpath=%s\n" $_func `pwd`'/'$_cfgpath
       _cfgpath=`pwd`'/'$_cfgpath
    fi
    if [ -d "$_cfgpath" ] ; then
       _cfgpath=$_cfgpath'/'mkiso.cfg
    fi

    # reconcile argument values config file
    if [ ! -z "${_cfgpath}" ] ; then
        proc_file_args ${_cfgpath} _defs $_aStrName
    fi

    # check the global defaults (no-dirops => build up, but do not
    # create or purge paths)
    default_mkiso_values $_aStrName 'no-dirops'

    eval "declare -A _vals="${!_aStrName}

    output_n_chars '=' 79
    dump_assoc _vals
    output_n_chars '=' 79

    # no need to serialize ${!_aStrName} is latest string...
    return 0
}

#
# process_create_args:
#
# $1 - IN: Name of argument values ass. array.
# $2 - IN: Name of argument definitions ass. array.
# $3 - IN: Name of help ass. array
#
function process_create_args {
    local _func=${FUNCNAME}
    local _aStrName=$1
    local _aDefName=$2
    local _aHelpName=$3
    local _defs
    local _help
    local _astr
    local _cfgpath
    local _vstr

    if [ -z "$_aStrName" ] ; then
        printf "%s: Missing arg values array\n" $_func
        return 1
    fi
    if [ -z "$_aDefName" ] ; then
        printf "%s: Missing arg defs array\n" $_func
        return 1
    fi
    if [ -z "$_aHelpName" ] ; then
        printf "%s: Missing arg help array\n" $_func
        return 1
    fi

    printf "%s: %s\n" $_func "$*"

    _astr=$(declare -p $_aDefName)
    eval "declare -A _defs="${_astr#*=}

    _astr=$(declare -p $_aHelpName)
    eval "declare -A _help="${_astr#*=}

    shift
    shift
    shift

    # Mandatory => must be specified or defaulted by the time
    # processing starts
    _defs['baseurl']='optional,multi,nolist'
    _defs['pkgdel']='optional,multi,list'
    _defs['pkglast']='optional,multi,list'
    _defs['yum-conf']='optional,single,nolist'
    _defs['misc-file']='optional,multi,list'
    _defs['misc-url']='optional,multi,list'
    _defs['yum_extra_args']='optional,multi,list'
    _defs['rpm-to-iso-pattern']='optional,single,nolist'

    _defs['pkgfile']='optional,single,nolist'
    _defs['pkg-rpm-regex']='optional,multi,list'
    _defs['pkg-rpm-xform']='optional,multi,list'
    _defs['pkg-rpm-skips']='optional,multi,list'
    _defs['pkg-rpm-path']='optional,single,nolist'
    _defs['copy-source']='optional,multi,list'

    _help['pkgfile']='file containing rpm list to add to pkglist'
    _help['pkg-rpm-regex']='regex to apply to pkglast'
    _help['pkg-rpm-xform']='transform to apply to pkglast'
    _help['pkg-rpm-skips']='rpm matches to skip'
    _help['pkg-rpm-path']='path of pkglist file after pkglist rpm is installed'
    _defs['copy-source']='add search paths relative to invocation path'

    # grab the command line arguments...
    process_args 'cmdline' _defs $_aStrName $@
    if [ $? -ne 0 ] ; then
        print_help aCreateHelp _help
        return 1
    fi

    eval "declare -A _vals="${!_aStrName}

    _cfgpath="${_vals[config]}"
    if [ -z "$_cfgpath" ] ; then
       _cfgpath='mkiso.cfg'
    fi
    if [ "${_cfgpath:0:1}" != "/" ] ; then
       tprint "$DEBUG_FLAG" "%s: _cfgpath=%s\n" $_func `pwd`'/'$_cfgpath
       _cfgpath=`pwd`'/'$_cfgpath
    fi
    if [ -d "$_cfgpath" ] ; then
       _cfgpath=$_cfgpath'/'mkiso.cfg
    fi

    # reconcile argument values config file
    if [ ! -z "${_cfgpath}" ] ; then
        proc_file_args ${_cfgpath} _defs $_aStrName
        if [ $? -ne 0 ] ; then
            print_help aCreateHelp _help
            return 1
        fi
    fi

    # check the global defaults
    default_mkiso_values $_aStrName
    if [ $? -ne 0 ] ; then
        print_help aCreateHelp _help
        return 1
    fi

    eval "declare -A _vals="${!_aStrName}

    cleanup_mounts _vals

    # before mandatory args are checked, try samba...
    local _sVals=''
    process_iso_url _vals _sVals
    if [ $? -ne 0 ] ; then
        printf "%s: process_iso_url FAILED!!!\n" $_func
        return $STATUS_FAIL
    fi
    eval "declare -A _vals="$_sVals

#    if [ -z "${_vals[iso-in]}" ] &&
#       [ ! -z "${_vals[samba_resource]}" ] ; then
#        query_samba_iso _vals _sVals
#        if [ $? -ne 0 ] ; then
#            printf "%s: ISO mount failed!!!\n" $_func
#            return 1
#        fi
#        eval "declare -A _vals="$_sVals
#    fi

    # wait we aren't done yet... we need to check for mandatory args
    check_mandatory_args _defs _vals
    if [ $? -ne 0 ] ; then
        print_help aCreateHelp _help
        return 1
    fi

    # dump out the data parsed....
    output_n_chars '=' 79
    dump_assoc _vals
    output_n_chars '=' 79

    # lastly serialize the array and update its string
    _astr=$(declare -p _vals)
    eval "$_aStrName="${_astr#*=}

    return 0
}

#
# process_rpm_to_iso_args:
#
# $1 - IN: Name of argument values ass. array.
# $2 - IN: Name of argument definitions ass. array.
# $3 - IN: Name of help ass. array
#
function process_rpm_to_iso_args {
    local _func=${FUNCNAME}
    local _aStrName=$1
    local _aDefName=$2
    local _aHelpName=$3
    local _defs
    local _help
    local _astr
    local _cfgpath
    local _vstr

    if [ -z "$_aStrName" ] ; then
        printf "%s: Missing arg values array\n" $_func
        return 1
    fi

    if [ -z "$_aDefName" ] ; then
        printf "%s: Missing arg defs array\n" $_func
        return 1
    fi

    if [ -z "$_aHelpName" ] ; then
        printf "%s: Missing arg help array\n" $_func
        return 1
    fi

    printf "%s: %s\n" $_func "$*"

    _astr=$(declare -p $_aDefName)
    eval "declare -A _defs="${_astr#*=}

    _astr=$(declare -p $_aHelpName)
    eval "declare -A _help="${_astr#*=}

    shift
    shift
    shift

    # Mandatory => must be specified or defaulted by the time
    # processing starts
    _defs[pkglist]='optional,multi,list'
    _defs[pkgdel]='optional,multi,list'
    _defs[pkglast]='optional,multi,list'
    _defs[yum-conf]='optional,single,nolist'
    _defs[baseurl]='optional,multi,nolist'
    _defs[misc-file]='optional,multi,list'
    _defs[misc-url]='optional,multi,list'
    _defs[yum_extra_args]='optional,multi,list'
    _defs[rpm-to-iso-pattern]='optional,single,nolist'

    _defs[rpm-file]='mandatory,single,nolist'
    _help[rpm-file]='filename with rpm list from rpm -qa'

    # grab the command line arguments...
    process_args 'cmdline' _defs $_aStrName $@
    if [ $? -ne 0 ] ; then
        print_help aRpm2IsoHelp _help
        return 1
    fi

    eval "declare -A _vals="${!_aStrName}

    _cfgpath="${_vals[config]}"
    if [ -z "$_cfgpath" ] ; then
       _cfgpath='mkiso.cfg'
    fi
    if [ "${_cfgpath:0:1}" != "/" ] ; then
       tprint "$DEBUG_FLAG" "%s: _cfgpath=%s\n" $_func `pwd`'/'$_cfgpath
       _cfgpath=`pwd`'/'$_cfgpath
    fi
    if [ -d "$_cfgpath" ] ; then
       _cfgpath=$_cfgpath'/'mkiso.cfg
    fi

    # reconcile argument values config file
    if [ ! -z "${_cfgpath}" ] ; then
        proc_file_args ${_cfgpath} _defs $_aStrName
        if [ $? -ne 0 ] ; then
            print_help aRpm2IsoHelp _help
            return 1
        fi
    fi

    # check the global defaults
    default_mkiso_values $_aStrName
    if [ $? -ne 0 ] ; then
        print_help aRpm2IsoHelp _help
        return 1
    fi

    eval "declare -A _vals="${!_aStrName}

    cleanup_mounts _vals

    # before mandatory args are checked, try samba...
    local _sVals=''
    process_iso_url _vals _sVals
    if [ $? -ne 0 ] ; then
        printf "%s: process_iso_url FAILED!!!\n" $_func
        return $STATUS_FAIL
    fi
    eval "declare -A _vals="$_sVals

    # wait we aren't done yet... we need to check for mandatory args
    _defs[iso-in]='optional,single,nolist'
    check_mandatory_args _defs _vals
    if [ $? -ne 0 ] ; then
        print_help aRpm2IsoHelp _help
        return 1
    fi

    # dump out the data parsed....
    output_n_chars '=' 79
    dump_assoc _vals
    output_n_chars '=' 79

    # lastly serialize the array and update its string
    _astr=$(declare -p _vals)
    eval "$_aStrName="${_astr#*=}

    return 0
}

#
# process_test_args:
#
# $1 - IN: Name of argument values ass. array.
# $2 - IN: Name of argument definitions ass. array.
# $3 - IN: Name of help ass. array
#
function process_test_args {
    local _func=${FUNCNAME}
    local _aStrName=$1
    local _aDefName=$2
    local _aHelpName=$3
    local _defs
    local _help
    local _astr
    local _cfgpath
    local _vstr

    if [ -z "$_aStrName" ] ; then
        printf "%s: Missing arg values array string\n" $_func
        return 1
    fi
    if [ -z "$_aDefName" ] ; then
        printf "%s: Missing arg defs array\n" $_func
        return 1
    fi
    if [ -z "$_aHelpName" ] ; then
        printf "%s: Missing arg help array\n" $_func
        return 1
    fi

    _astr=$(declare -p $_aDefName)
    eval "declare -A _defs="${_astr#*=}

    _astr=$(declare -p $_aHelpName)
    eval "declare -A _help="${_astr#*=}

    shift
    shift
    shift

    printf "%s: %s\n" $_func "$*"

    # override mandatory defaults...
    _defs[pkglist]='optional,multi,list'
    _defs[pkgdel]='optional,multi,list'
    _defs[pkglast]='optional,multi,list'
    _defs[yum-conf]='optional,single,nolist'
    _defs[baseurl]='optional,multi,nolist'
    _defs[misc-file]='optional,multi,list'
    _defs[misc-url]='optional,multi,list'
    _defs[yum_extra_args]='optional,multi,list'
    _defs[rpm-to-iso-pattern]='optional,single,nolist'

    # grab the command line arguments...
    process_args 'cmdline' _defs $_aStrName $@
    if [ $? -ne 0 ] ; then
        print_help aTestHelp _help
        return 1
    fi

     eval "declare -A _vals="${!_aStrName}

    _cfgpath="${_vals[config]}"
    if [ -z "$_cfgpath" ] ; then
       _cfgpath='mkiso.cfg'
    fi
    if [ "${_cfgpath:0:1}" != "/" ] ; then
       tprint "$DEBUG_FLAG" "%s: _cfgpath=%s\n" $_func `pwd`'/'$_cfgpath
       _cfgpath=`pwd`'/'$_cfgpath
    fi
    if [ -d "$_cfgpath" ] ; then
       _cfgpath=$_cfgpath'/'mkiso.cfg
    fi

    # reconcile argument values config file
    if [ ! -z "${_cfgpath}" ] ; then
        proc_file_args ${_cfgpath} _defs $_aStrName
        if [ $? -ne 0 ] ; then
            print_help aTestHelp _help
            return 1
        fi
    fi

    # check the global defaults
    default_mkiso_values $_aStrName
    if [ $? -ne 0 ] ; then
        print_help aTestHelp _help
        return 1
    fi

    eval "declare -A _vals="${!_aStrName}

    output_n_chars '=' 79
    dump_assoc _vals
    output_n_chars '=' 79

    # wait we aren't done yet... check mandatory args
    check_mandatory_args _defs _vals
    if [ $? -ne 0 ] ; then
        print_help aTestHelp _help
        return 1
    fi

    # no need to serialize ${!_aStrName} is latest string...
    return 0
}

#
# process_repo_args:
#
# $1 - IN: Name of argument values ass. array.
# $2 - IN: Name of argument definitions ass. array.
# $3 - IN: Name of help ass. array
#
function process_repo_args {
    local _func=${FUNCNAME}
    local _aStrName=$1
    local _aDefName=$2
    local _aHelpName=$3
    local _defs
    local _help
    local _astr
    local _cfgpath
    local _vstr

    if [ -z "$_aStrName" ] ; then
        printf "%s: Missing arg values array\n" $_func
        return 1
    fi
    if [ -z "$_aDefName" ] ; then
        printf "%s: Missing arg defs array\n" $_func
        return 1
    fi
    if [ -z "$_aHelpName" ] ; then
        printf "%s: Missing arg help array\n" $_func
        return 1
    fi

    printf "%s: %s\n" $_func "$*"

    _astr=$(declare -p $_aDefName)
    eval "declare -A _defs="${_astr#*=}

    _astr=$(declare -p $_aHelpName)
    eval "declare -A _help="${_astr#*=}

    shift
    shift
    shift

    # Mandatory => must be specified or defaulted by the time
    # processing starts
    _defs['baseurl']='optional,multi,nolist'
    _defs['pkgdel']='optional,multi,list'
    _defs['pkglast']='optional,multi,list'
    _defs['yum-conf']='optional,single,nolist'
    _defs['misc-file']='optional,multi,list'
    _defs['iso-in']='optional,single,nolist'
    _defs['iso-out']='optional,single,nolist'
    _defs['misc-url']='optional,multi,list'
    _defs['yum_extra_args']='optional,multi,list'
    _defs['rpm-to-iso-pattern']='optional,single,nolist'

    # grab the command line arguments...
    process_args 'cmdline' _defs $_aStrName $@
    if [ $? -ne 0 ] ; then
        print_help aCreateHelp _help
        return 1
    fi

    eval "declare -A _vals="${!_aStrName}

    _cfgpath="${_vals[config]}"
    if [ -z "$_cfgpath" ] ; then
       _cfgpath='mkiso.cfg'
    fi
    if [ "${_cfgpath:0:1}" != "/" ] ; then
       tprint "$DEBUG_FLAG" "%s: _cfgpath=%s\n" $_func `pwd`'/'$_cfgpath
       _cfgpath=`pwd`'/'$_cfgpath
    fi
    if [ -d "$_cfgpath" ] ; then
       _cfgpath=$_cfgpath'/'mkiso.cfg
    fi

    # reconcile argument values config file
    if [ ! -z "${_cfgpath}" ] ; then
        proc_file_args ${_cfgpath} _defs $_aStrName
        if [ $? -ne 0 ] ; then
            print_help aCreateHelp _help
            return 1
        fi
    fi

    # check the global defaults
    default_mkiso_values $_aStrName
    if [ $? -ne 0 ] ; then
        print_help aCreateHelp _help
        return 1
    fi

    eval "declare -A _vals="${!_aStrName}

    cleanup_mounts _vals

    # wait we aren't done yet... we need to check for mandatory args
    check_mandatory_args _defs _vals
    if [ $? -ne 0 ] ; then
        print_help aCreateHelp _help
        return 1
    fi

    # dump out the data parsed....
    output_n_chars '=' 79
    dump_assoc _vals
    output_n_chars '=' 79

    # lastly serialize the array and update its string
    _astr=$(declare -p _vals)
    eval "$_aStrName="${_astr#*=}

    return 0
}

#
# build_file:
#
# $1 -  I/O: Name of Arguments array as a STRING
# $2 -  IN:  Argument key
# $3 -  IN:  Default Base Directory Path
# $4 -  IN:  Default file name
#
function build_file {
    local _astr=$1
    local _argsKey=$2
    local _defDir=$3
    local _defFile=$4

    local _func=${FUNCNAME}
    local _fpath
    local _var
    local _bfArgs
    local _dummy
    local _astr

    if [ -z "$_astr" ] || [ -z "$_argsKey" ] || \
       [ -z "$_defDir" ] || [ -z "${!_astr}" ] ; then
        printf "%s: Incomplete args\n" $_func
        return $STATUS_FAIL
    fi

    _str="declare -A _dummy=${!_astr}"
    eval "declare -A _bfArgs="${_str#*=}

    _fpath="${_bfArgs[$_argsKey]}"
    if [ -z "$_fpath" ] ; then
       # No provided default means build up the path only if
       # something is specified...
       if [ -z "$_defFile" ] ; then
           return $STATUS_OK
       fi
       _fpath=$_defFile
    fi
    # leave anything that looks like a URL alone...
    if [[ $_fpath =~ ^([A-Za-z]+): ]] ; then
        return $STATUS_OK
    fi
    _pos=1
    if [ "${_fpath:0:1}" == "~" ] ; then
        if [ "${_fpath:0:2}" == "~/" ] ; then
            _pos=2
        fi
        _fpath="$HOME"/"${_fpath:$_pos}"
    fi
    if [ "${_fpath:0:1}" != "/" ] && \
       [[ "${_fpath:0:1}" =~ [0-9a-zA-Z\.] ]] ; then
       _fpath=$_defDir'/'$_fpath
    fi
    if [ -d "$_fpath" ] ; then
       _fpath=$_fpath'/'$_defFile
    fi
    _bfArgs[$_argsKey]=$_fpath

    printf "%s: args[%s]=%s\n" $_func $_argsKey ${_bfArgs[$_argsKey]}

    # serialize current array and update the array string...
    _var=$(declare -p _bfArgs)
    eval "$_astr="${_var#*=}
    return $STATUS_OK
}

#
# build_path:
#
# $1 - OUT: constructed path
# $2 -  IN: Name of array STRING
# $3 -  IN: argument key
# $4 -  IN: Default Base Directory Path
# $5 -  IN: Default Subdirectory
# $6 -  IN: Actions (delete, create, prep)
# $7 -  IN: Is sudo needed to delete?
#
function build_path {
    local _func=${FUNCNAME}
    local _pathout=$1
    local _argValsStr=$2
    local _argKey=$3
    local _defaultDir=$4
    local _defaultLeaf=$5
    local _action=$6
    local _sudo=$7
    local _mypath
    local _mytouch

    local _args
    local _var
    local _str
    local _dummy

    if [ -z "$_pathout" ] || [ -z "$_argValsStr" ] || \
       [ -z "$_argKey" ] || [ -z "$_defaultDir" ] || \
       [ -z "$_defaultLeaf" ] || [ -z "${!_argValsStr}" ] ; then
        printf "%s: Incomplete args\n" $_func
        return 1
    fi

    tprint "$DEBUG_FLAG" "%s (%s %s %s %s %s %s)\n" $_func $1 $2 $3 $4 $5 $6

    _str="declare -A _dummy=${!_argValsStr}"
    eval "declare -A _args="${_str#*=}

    if [ -z "${_args[$_argKey]}" ] ; then
        if [ "$_defaultLeaf" != "." ] ; then
            _args[$_argKey]="$_defaultDir/$_defaultLeaf"
        else
            _args[$_argKey]="$_defaultDir"
        fi
    elif [ ${_args[$_argKey]:0:1} != '/' ] ; then
        _args[$_argKey]=$_defaultDir'/'${_args[$_argKey]}
    fi
    _mypath=${_args[$_argKey]}
    eval "$_pathout=${_mypath}"

    if [ ! -z "$_action" -a ! -z "$_mypath" ] ; then
        if [ $_action == 'delete' -o $_action == 'prep' ] ; then
             _output=`ls -l $WORKSPACE`
             tprint "$DEBUG_FLAG" "%s\n" "$_output"
             purge_mkiso_dir "$_mypath" $_func "$_sudo"
             if [ $? -ne 0 ] ; then
                 printf "%s:Failed to delete '%s'\n" $_func $_mypath
                 return 1
             fi
             printf "%s: ... Purged %s\n" $_func $_mypath
        fi
        if [ $_action == 'create' -o $_action == 'prep' ] ; then
             if [ ! -d "$_mypath" ] ; then
                 mkdir -p $_mypath
                 if [ $? -ne 0 ] ; then
                     printf "%s: Failed to create %s\n" $_func $_mypath
                     return 1
                 fi
                 _mytouch="$_mypath/$MKISO_WORKSPACE_ID"
                 touch "$_mytouch" &> /dev/null
                 if [ $? -ne 0 ] ; then
                     printf "%s: Failed to create %s\n" $_func $_mytouch
                     return 1
                 fi
             fi
             printf "%s: ... Created %s\n" $_func $_mypath
        fi
    fi

    # Should the array entry be updated on return, if so
    # additional code both here and at func invocation
    # site will be required...

    tprint "$DEBUG_FLAG" "%s: %s=%s\n" $_func $_pathout ${_args[$_argKey]}

    # serialize current array and apply to original string
    _var=$(declare -p _args)
     eval "$_argValsStr="${_var#*=}

    return 0
}

#
# build_pkg_list_rpm_name:
#
# Generates args[pkg_list_rpm] from:
#    - ${_args[pkg-rpm-regex]}
#    - ${_args[pkg-rpm-xform]}
#    - ${_args[pkg-rpm-skips]}
#    - ${_args[pkglist]}
#    - ${_args[pkglast]}
#
# $1: Name of global parameters associative array.
#
# Match pkg-rpm-regex against pkglist, pkglast parameters to extract 
# package name sub-strings transformed into a package list rpm
# name using string in pkg-rpm-xform
#
# To replace regx ${BASH_REMATCH[N]} collected from the regex match
# Use {{N}} in the transform string(pkg-rpm-xform) where N is the 
# matching substring number. {{N?}} Allows replacement by an empty match.
#
# Returns 0 if successful, 1 otherwise.
#
function build_pkg_list_rpm_name() { 
    local _func=${FUNCNAME}
    local _argStr=$1
    local _args

    if [ -z "$_argStr" ] || [ -z "${!_argStr}" ] ; then
        printf "%s: Invalid arguments\n" $_func
        return 1
    fi

    # de-serialize                                                                                                                                                                                                                                                                                                      
    _str="declare -A _dummy=${!_argStr}"
    eval "declare -A _args="${_str#*=}
    
    # converts any versions of 128T into directory paths
    _pkgList=${_args[pkglist]}
    _pkgLast=${_args[pkglast]}
    _pkgs=(_pkgList _pkgLast)
    patterns=(${_args[pkg-rpm-regex]})
    xforms=(${_args[pkg-rpm-xform]})
    skips=(${_args[pkg-rpm-skips]})
    exlist="patterns xforms skips"
    outstr=''
    declare -A matches

    for name in $exlist[@] ; do 
	exprs=${!name}
	for expr in ${exprs[@]} ; do
	    length=${#expr}
	    if [ $length -ge 2 ] ; then
		last=$((length-1))
		if [ ${expr:0:1} != '"' ] ||
		    [ ${expr:$last} != '"' ] ; then
		    printf "%s: Malformatted %s entry in %s -- 1st and last chars must be \"s, bailing\n" ${name} ${_func} ${pattern}
		    return 1
		fi
            else
		printf "%s: Malformatted %s entry in %s -- 1st and last chars must be \"s, bailing\n" ${name} ${_func} ${pattern}
		return 1
	    fi
	done
    done

    printf "%s: PATTERNS: %s\n\n" ${_func} "${pattern[@]}"
    printf "%s:   XFORMS: $%s\n\n" ${_func} "${xforms[@]}"
    printf "%s:    SKIPS: $%s\n\n" ${_func} "${skips[@]}"

    for list in ${_pkgs[@]} ; do
	_rpmList=''
	_grpList=''
	_copyList=''
	pre_process_rpm_list ${list} _rpmList _grpList _copyList    
	if [ $? -ne 0 ] ; then
	    printf "%s: Unable to pre_process_rpm_list %s\n" ${_func} ${list}
	    return 1
	fi
	for rpm in ${_rpmList[@]} ; do
	    patndx=0
	    skipit=1
	    while [ $patndx -lt ${#skips[@]} ] ; do
		pattern=${skips[$patndx]}
		pattern=${pattern:1:-1}
		if [[ $rpm =~ $pattern ]] ; then
		    printf "${_func}: pattern ${pattern} skips rpm ${rpm}\n"
		    skipit=0
		    break
		fi
		patndx=$((patndx+1))
	    done
	    if [ $skipit -eq 0 ] ; then
		continue
	    fi
	    patndx=0
	    outstr=''
	    matches={}
	    while [ $patndx -lt ${#patterns[@]} ] ; do
		pattern=${patterns[$patndx]}
		pattern=${pattern:1:-1}
		# printf "${_func}: TRY ${pattern} AGAINST ${rpm}\n"
		if [[ $rpm =~ $pattern ]] ; then
		    printf "${_func}: pattern ${pattern} matched rpm ${rpm}\n"
		    matchndx=0
		    while [ $matchndx -lt 10 ] ; do
			if [ ! -z "${BASH_REMATCH[$matchndx]}" ] ; then
			    matches[$matchndx]=${BASH_REMATCH[$matchndx]}
			    printf "${_func}: MATCHES[$matchndx]=${matches[$matchndx]}\n"
			fi
			matchndx=$((matchndx+1))
		    done
		    break
		fi
		patndx=$((patndx+1))
	    done
	    if [ $patndx -lt ${#patterns[@]} ] ; then
		xform=${xforms[$patndx]}
		xform=${xform:1:-1}
		if [ ! -z "${xform}" ] ; then
                   outstr=$xform
		    for key in ${!matches[@]} ; do
		         replacement=${matches[$key]}
		         outstr=${outstr//\{\{$key\}\}/$replacement}
		    done
		    key=1
		    # replace outstr
                    while [ $key -le 10 ] ; do
		        outstr=${outstr//\{\{$key?\}\}/}
			key=$((key+1))
                    done
	        fi
		break
	    fi
        done
	if [[ $outstr != '' ]] ; then
	    if [[ ! $outstr =~ .*?\{\{.*?\}\}.* ]] ; then
	       break
	    else
		printf "%s: Incomplete Replacement %s !!!\n" $_func $outstr
		exit 1
	    fi
	fi
    done

    _args[pkg_list_rpm]=$outstr
    printf "${_func}: FINAL-XFORM=${_args[pkg_list_rpm]}\n"

    # serialize current array and apply to original string                                                                                                                                                                                                                                                              
    _var=$(declare -p _args)
    eval "$_argStr="${_var#*=}

    return 0
}

#
# load_pkg_list_from_file:
# 
# $1: Serialized parameter/argument array.
# $2: Full path of file to load rpm list from...
#
# Loads the package list from $2 (usually ${_args[pkgfile]}) into
# _args[pkglist], also appending ${_args[pkg_list_rpm]} to the list
# as this too should ultimately be installed...
#        
function load_pkg_list_from_file {
    local _func=${FUNCNAME}
    local _argStr=$1
    local _filepath=$2
    local _args

    if [ -z "$_argStr" ] || [ -z "${!_argStr}" ] ; then
        printf "%s: Invalid arguments\n" $_func
        return 1
    fi

    if [ -z "$_filepath" ] || \
	[ "$_filepath" == "" ] ; then
	printf "%s: No filepath provided\n" ${_func} 
	return 1
    fi

    if [ ! -f "$_filepath" ] ; then
	printf "%s: %s missing\n" ${_func} ${_filepath}
	return 1
    fi 

   _str="declare -A _dummy=${!_argStr}"
    eval "declare -A _args="${_str#*=}
    
    printf "%s: Loading package list from %s\n" ${_func} "${_filepath}"

    tmpPkgLst=""
    while read line ; do
        # remove whitespace
        line=${line// /}
        if [ ${line} == "" ] ; then
            continue
        fi
        if [ ${line:0:1} == "#" ] ; then
            continue
        fi 
	printf "...Adding %s from %s\n" $line ${_filepath}
	if [ "${tmpPkgList}" == "" ] ; then
	    tmpPkgList=${line}
	else 
	    tmpPkgList="${tmpPkgList} ${line}"
	fi
    done < ${_filepath}

    if [ -z "${_args[pkglist]}" ] || \
        [ "${_args[pkglist]}" == '' ] ; then
	_args[pkglist]="${tmpPkgList}"
    else 
	_args[pkglist]="${_args[pkglist]} ${tmpPkgList}"
    fi

    if [ ! -z "${_args[pkg_list_ks]}" ] && \
        [ "${_args[pkg_list_ks]}" != '' ] ; then
	_args[pkg_list_ks]="${_args[pkg_list_ks]} ${_args[pkg_list_rpm]}"
    fi

    # If it's set, add in the derived rpm pattern
    if [ ! -z "${_args[pkg_list_rpm]}" ] && \
        [ "${_args[pkg_list_rpm]}" != '' ] ; then
	_args[pkglist]="${_args[pkglist]} ${_args[pkg_list_rpm]}"
    fi

    # serialize current array and apply to original string
    _var=$(declare -p _args)
    eval "$_argStr="${_var#*=}

    return 0
}

#
# apply_arg_default:
#
#
function apply_arg_default {
    local _func=${FUNCNAME}
    local _argStr=$1
    local _argKey=$2
    local _argDefault=$3
    local _args

    if [ -z "$_argStr" ] || [ -z "${!_argStr}" ] || \
       [ -z "$_argKey" ] || [ -z "${_argDefault}" ] ; then
        printf "%s: Invalid arguments\n" $_func
        return 1
    fi

    _str="declare -A _dummy=${!_argStr}"
    eval "declare -A _args="${_str#*=}

    if [ -z "${_args[$_argKey]}" ] ; then
        _args[$_argKey]="$_argDefault"
        tprint "$DEBUG_FLAG" "%s: ARGS[%s]=%s\n" $_func $_argKey "$_argDefault"

        # serialize current array and apply to original string
        _var=$(declare -p _args)
        eval "$_argStr="${_var#*=}
    fi

    return 0
}

#
# default_mkiso_values:
#
# $1 - argument values ass. array string....
# $2 - should directories be manipulated as opposed to just
#      constructed (latter is for show command). Not set or
#      'dir-ops' => manipulate, 'no-dir-ops' => do not.
#
function default_mkiso_values {
   local _func=${FUNCNAME}
   local _aStrName=$1
   local _dirops=$2
   local _argVals
   local _aStr

   tprint "$DEBUG_FLAG" "%s: %s\n" $_func "$@"

   if [ -z $"_argStrName" ] ; then
       printf "%s: Argument values array name not provided\n" $_func
       return 1
   fi
   if [ -z "$_dirops" ] ; then
       _dirops='dirops'
   fi

   # Create a local array from the string...
   eval "declare -A _argVals="${!_aStrName}

   key='workspace'
   if [ -z "${_argVals[$key]}" ] ; then
       _argVals[$key]="$HOME/mkiso-workspace"
   fi
   WORKSPACE=${_argVals[$key]}
   if [ $WORKSPACE == $HOME ] ; then
       printf "%s ERROR workspace cannot be home directory!!!!\n" $_func
       return 1
   fi
   # protect against workspace sudo ops where they don't belong...
   if [ -d $WORKSPACE -a ! -O $WORKSPACE ] ; then
       printf "%s ERROR workspace %s not owned by invoker!!!!\n" $_func $WORKSPACE
       return 1
   fi
   if [ ! -d $WORKSPACE ] ; then
       mkdir -p $WORKSPACE
   fi

   # Perverse array content accross calls by serializing first
   _aStr=$(declare -p _argVals)
   _aStr=${_aStr#*=}

   # The path used to find the config file defaults as the
   # path for the config directory as well.
   local _cfgarg=${_argVals['config']}
   local _cfgpath=`dirname $_cfgarg`
   echo "CFGARG=$_cfgarg"
   echo "CFGPATH=$_cfgpath"
   if [[ -z "$_cfgpath" ]] || [[ "$_cfgpath" == "." ]]; then
       _cfgpath=${MKISO_INVOKED_PATH}
       echo "CFGPATH.0=$_cfgpath"
   fi
   if [[ ${_cfgpath:0:1} != "/" ]] ; then
       _cfgpath=${MKISO_INVOKED_PATH}/${_cfgpath}
       echo "CFGPATH.1=$_cfgpath"
   fi

   echo "CFGPATH.2=$_cfgpath"

   # Build path variables (these cannot currently be overriden)
   if [ $_dirops == 'dirops' ] ; then
       build_path YUM_INSTALL_PATH _aStr yum_install_path $WORKSPACE \
           yum_install_root prep sudo
       build_path YUM_RPM_PATH _aStr yum_rpm_path $WORKSPACE yum_rpm_downloads prep
       build_path ISO_MOUNT_PATH _aStr iso_mount_path $WORKSPACE iso-mnt create
       build_path ISO_STAGING_PATH _aStr iso_staging_path $WORKSPACE iso-staging prep
       build_path ISO_EFI_MOUNT_PATH _aStr iso_efi_mount_path $WORKSPACE efi-mnt create
       build_path SAMBA_MOUNT_PATH _aStr samba_mount_path $WORKSPACE samba-mnt create
       build_path MKISO_CONFIG_PATH _aStr config-path ${_cfgpath} config
   else
       build_path YUM_INSTALL_PATH _aStr yum_install_path $WORKSPACE \
              yum_install_root
       build_path YUM_RPM_PATH _aStr yum_rpm_path $WORKSPACE yum_rpm_downloads
       build_path ISO_MOUNT_PATH _aStr iso_mount_path $WORKSPACE iso-mnt
       build_path ISO_STAGING_PATH _aStr iso_staging_path $WORKSPACE iso-staging
       build_path ISO_EFI_MOUNT_PATH _aStr iso_efi_mount_path $WORKSPACE efi-mnt
       build_path SAMBA_MOUNT_PATH _aStr samba_mount_path $WORKSPACE samba-mnt
       build_path MKISO_CONFIG_PATH _aStr config-path ${_cfgpath} config
   fi

   # build up the default yum config path
   build_file _aStr yum_repo_src_conf  /etc yum.conf
   build_file _aStr yum_repo_dest_conf /etc yum.conf

   # build up the kickstart config path
   build_file _aStr ks-file $MKISO_CONFIG_PATH 128T-ks.cfg

   # build up the iso input file path (only if provided)
   build_file _aStr iso-in $MKISO_DEFAULT_PATH

   apply_arg_default _aStr yum_repo_src_path  /etc/yum.repos.d
   apply_arg_default _aStr yum_repo_dest_path /etc/yum.repos.d
   apply_arg_default _aStr yum_pki_src_path  /etc/pki/rpm-gpg
   apply_arg_default _aStr yum_pki_dest_path /etc/pki/rpm-gpg

   # set default samba information....
   apply_arg_default _aStr samba_resource //files.128technology.com/FileShare
   apply_arg_default _aStr samba_user $USER
   apply_arg_default _aStr samba_iso_file 'Engineering/Repo Clones/CentOS/7.3.1611/isos/x86_64/CentOS-7-x86_64-Minimal-1611.iso'

   # build up a yum config filename (only if provided)
   build_file _aStr yum-conf $MKISO_CONFIG_PATH

   # build up a rpm filename (only if provided)
   build_file _aStr rpm-file $MKISO_CONFIG_PATH

   # build up package list filename (only if provided)
   build_file _aStr pkgfile $MKISO_CONFIG_PATH

   # build up an ISO output filename
   build_file _aStr iso-out $WORKSPACE 128T.iso

   apply_arg_default _aStr os-version 7
   apply_arg_default _aStr pkgdir Packages

   apply_arg_default _aStr iso.vol 128T_VOL
   apply_arg_default _aStr iso.volset 128T_VOL_SET
   apply_arg_default _aStr iso.app 128Tech_ISO_Creator

   # Most Template file variables should be overridable
   apply_arg_default _aStr iso.custom_menu_label 128T
   apply_arg_default _aStr iso.custom_menu_name "128T Router (CentOS 7.X Base)"
   apply_arg_default _aStr iso.boot_timeout 30
   apply_arg_default _aStr iso.linux_timeout 300
   apply_arg_default _aStr iso.linux_title "128T Router Install"
   apply_arg_default _aStr iso.linux_background splash.png
   apply_arg_default _aStr iso.linux_display boot.msg

   # By default, prompt before installing tools
   apply_arg_default _aStr prompt-for-tools "on"

   # Build file where the list of rpms will be installed to... 
   # yum_install_root can't be used as no de-serialization has been done yet
   build_file _aStr pkg-rpm-path $YUM_INSTALL_PATH

   # Apply regex transforms to args[pkglast][0] to come up with an rpm
   # name to download to extract an rpm list from...
   if [ -z "${_argVals[pkgfile]}" ] && \
       [ ! -z "${_argVals[pkg-rpm-path]}" ] ; then
       build_pkg_list_rpm_name _aStr
   fi

   # regenerate the array from the string...
   eval "declare -A _argVals"=${_aStr}

   if [ ! -z "${_argVals[pkgfile]}" ] ; then
       # no need to serialize again as nothing has changed
       load_pkg_list_from_file _aStr "${_argVals[pkgfile]}"
       eval "declare -A _argVals"=${_aStr}
   fi

   # must be done after array reconstructed from string
   ISO_CREATE_FILE_PATH="${_argVals[iso-out]}"
   YUM_CONF_FILE_PATH="${_argVals[yum-conf]}"
   ISO_RELEASE_VERSION="${_argVals[os-version]}"
   ISO_PACKAGES_DIR="${_argVals[pkgdir]}"
   # not to be defaulted...
   ISO_PACKAGE_LIST=${_argVals[pkglist]}

   # This one cannot be overriden for now as it ties the mkisofs
   # volume to the volume grub bootloader specifies...
   _argVals[iso.volume]=${_argVals[iso.vol]}
   # This also cannot be overriden as i is the name of the kickstart
   # file provided in the ks-file parameter
   _argVals[iso.kickstart]=`basename ${_argVals[ks-file]}`

   # Perverse array content accross calls by serializing first
   _aStr=$(declare -p _argVals)
   _aStr=${_aStr#*=}

   apply_arg_default _aStr rsync-opts "--exclude $ISO_PACKAGES_DIR"

   # save the values array string...
   eval $_aStrName='${_aStr}'

   return 0
}


#
# do_cmd_show_params
#
# $@ - command line arguments
#
function do_cmd_show_params {
    local _func=${FUNCNAME}
    tprint "$DEBUG_FLAG" "%s:: %s\n" $_func "$*"

    aname_to_string MKISO_VALS _mstr
    process_show_args _mstr ARG_DEFS ARG_HELP $@

    return 0
}

#
# do_cmd_iso_test:
#
#
function do_cmd_iso_test {
    local _func=${FUNCNAME}
    local _mstr

    printf "%s:: %s\n" $_func "$*"

    aname_to_string MKISO_VALS _mstr
    process_test_args _mstr ARG_DEFS ARG_HELP $@
    exit_on_fail "$_func: process_rpm_to_iso_args" $?
    eval "declare -A MKISO_VALS="$_mstr

    test_iso_install MKISO_VALS
    exit_on_fail "$_func: test_iso_install" $?

    cleanup_mounts MKISO_VALS

    # output SUCCESS banner...
    output_n_chars '#' 75
    printf "#       ISO Install SUCCESS\n"
    printf "# \n"
    printf "# for %s\n" "${MKISO_VALS[iso-in]}"
    printf "# \n"
    printf "# fine-print:\n"
    printf "# ...to the extent testable by yum. For greater \n"
    printf "# ...certainty, install it on a VM or physical HW :-)\n"
    output_n_chars '#' 75

    return 0
}

#
# do_cmd_create:
#
# $@ - command line arguments
#
function do_cmd_create {
    local _func=${FUNCNAME}
    local _mstr
    local _copy_config

    printf "%s:: %s\n" $_func "$*"

    check_installed_rpms ${MKISO_VALS[prompt-for-tools]}
    exit_on_fail "check_installed_rpms" $?

    aname_to_string MKISO_VALS _mstr
    process_create_args _mstr ARG_DEFS ARG_HELP $@
    exit_on_fail "$_func: process_create_args" $?
    eval "declare -A MKISO_VALS="$_mstr

    # ignore the rpms from the ISO -- only use what we learn from yum
    copy_iso "${MKISO_VALS[iso-in]}" $ISO_MOUNT_PATH $ISO_STAGING_PATH \
        "${MKISO_VALS[rsync-opts]]}"
    exit_on_fail "copy_iso" $?

    # Add list of rpms from file installed by rpm to the rpm list...
    # This uses the 'correct approach' --  a faster approach might be
    # to perform yumdownloader on the rpm and get at the directory
    # structure and file directly which would not require reconstructing
    # the yum cache.
    _copy_config='copy-config'
    # save the original package list for use by populate_kickstart
    MKISO_VALS[pkg_list_ks]=${MKISO_VALS[pkglist]}

        printf "${TERMINAL_COLOR_GREEN}%.s=" % {1..79}
        printf "\n" 
	dump_assoc MKISO_VALS
        printf "%.s=" % {1..79}
        printf "${TERMINAL_STYLE_NORMAL}\n"

    if [ -z ${MKISO_VALS[pkgfile]} ] && \
	[ ! -z ${MKISO_VALS[pkg_list_rpm]} ] && \
	[ ${MKISO_VALS[pkg_list_rpm]} != '' ] ; then
	yum_download MKISO_VALS 'install' 'copy-config' 'pkg_list_rpm'
	exit_on_fail "Yum Install" $?
	aname_to_string MKISO_VALS _mstr
	load_pkg_list_from_file _mstr ${MKISO_VALS[pkg-rpm-path]}
	exit_on_fail "Load Package List from File" $?
	eval "declare -A MKISO_VALS"=${_mstr}

        printf "${TERMINAL_COLOR_BLUE}%.s=" % {1..79}
        printf "\n" 
	dump_assoc MKISO_VALS
        printf "%.s=" % {1..79}
        printf "${TERMINAL_STYLE_NORMAL}\n"
	
	# purge required, otherwise required rpms will not be downloaded :-(
	purge_mkiso_dir ${YUM_INSTALL_PATH} ${_func} 'sudo'
	exit_on_fail "Failed to Purge Install Root..." $?
	mkdir -p ${YUM_INSTALL_PATH}
	exit_on_fail "Failed to Create Install Root..." $?
        touch "${YUM_INSTALL_PATH}/${MKISO_WORKSPACE_ID}"
	exit_on_fail "Failed to Unprotect Install Root..." $?
    else
        printf "${TERMINAL_COLOR_BLUE}%.s=" % {1..79}
        printf "\n" 
	printf "PACKAGE LIST NOT LOADED FROM RPM... Continuing\n"
        printf "%.s=" % {1..79}
        printf "${TERMINAL_STYLE_NORMAL}\n" 
    fi

    yum_download MKISO_VALS 'no-install' ${_copy_config}
    exit_on_fail "Yum Download" $?

    move_rpms_to_staging $YUM_RPM_PATH $ISO_STAGING_PATH
    exit_on_fail "move_rpms_to_staging" $?

    copy_files MKISO_VALS 'misc-file'
    exit_on_fail "copy_files(misc-file)" $?

    copy_urls MKISO_VALS
    exit_on_fail "copy_urls" $?

    populate_kickstart MKISO_VALS 'pkg_list_ks'
    exit_on_fail "populate_kickstart" $?

    copy_files MKISO_VALS 'template'
    exit_on_fail "copy_files(template)" $?

    enable_uefi_boot $ISO_STAGING_PATH $ISO_EFI_MOUNT_PATH
    exit_on_fail "enable_uefi_boot failed" $?

    mkiso $ISO_STAGING_PATH $ISO_CREATE_FILE_PATH ${MKISO_VALS[iso.vol]} \
          ${MKISO_VALS[iso.volset]} ${MKISO_VALS[iso.app]}
    exit_on_fail "mkiso failed" $?

    cleanup_mounts MKISO_VALS

    # SUCCESS banner...
    output_n_chars '#' 75
    printf "#                    ISO Creation SUCCESS\n"
    printf "# \n"
    printf "# New ISO is located at: \n"
    printf "# %s\n" ${ISO_CREATE_FILE_PATH}
    output_n_chars '#' 75
}

#
# do_cmd_rpm_to_iso:
#
# $@ - command line arguments
#
# The only differece between this function and do_cmd_create is
# the use of rpm_download to download an explicit list of rpms
# an opposed to resolving packages.
#
function do_cmd_rpm_to_iso {
    local _func=${FUNCNAME}
    local _mstr

    printf "%s:: %s\n" $_func "$*"

    check_installed_rpms ${MKISO_VALS[prompt-for-tools]}
    exit_on_fail "check_installed_rpms" $?

    aname_to_string MKISO_VALS _mstr
    process_rpm_to_iso_args _mstr ARG_DEFS ARG_HELP $@
    exit_on_fail "$_func: process_rpm_to_iso_args" $?
    eval "declare -A MKISO_VALS="$_mstr

    # ignore the rpms from the ISO -- only use what we learn from yum
    copy_iso "${MKISO_VALS[iso-in]}" $ISO_MOUNT_PATH $ISO_STAGING_PATH \
        "${MKISO_VALS[rsync-opts]]}"
    exit_on_fail "copy_iso" $?

    rpm_download MKISO_VALS
    exit_on_fail "RPM Download" $?

    move_rpms_to_staging $YUM_RPM_PATH $ISO_STAGING_PATH
    exit_on_fail "move_rpms_to_staging" $?

    copy_files MKISO_VALS 'misc-file'
    exit_on_fail "copy_files(misc-file)" $?

    copy_urls MKISO_VALS
    exit_on_fail "copy_urls" $?

    populate_kickstart MKISO_VALS
    exit_on_fail "populate_kickstart" $?

    copy_files MKISO_VALS 'template'
    exit_on_fail "copy_files(template)" $?

    enable_uefi_boot $ISO_STAGING_PATH $ISO_EFI_MOUNT_PATH
    exit_on_fail "enable_uefi_boot failed" $?

    mkiso $ISO_STAGING_PATH $ISO_CREATE_FILE_PATH ${MKISO_VALS[iso.vol]} \
          ${MKISO_VALS[iso.volset]} ${MKISO_VALS[iso.app]}
    exit_on_fail "mkiso failed" $?

    cleanup_mounts MKISO_VALS

    # SUCCESS banner...
    output_n_chars '#' 75
    printf "#                    ISO Creation SUCCESS\n"
    printf "# \n"
    printf "# ISO from RPM List is located at: \n"
    printf "# %s\n" ${MKISO_VALS[iso-out]}
    output_n_chars '#' 75
}

#
# do_cmd_repo:
# $@ - command line arguments
#
function do_cmd_repo {
    local _func=${FUNCNAME}
    local _mstr

    printf "%s:: %s\n" $_func "$*"

    aname_to_string MKISO_VALS _mstr
    process_repo_args _mstr ARG_DEFS ARG_HELP $@
    exit_on_fail "$_func: process_repo_args" $?
    eval "declare -A MKISO_VALS="$_mstr

    yum_download MKISO_VALS 'no-install'
    exit_on_fail "Yum Download" $?

    move_rpms_to_staging $YUM_RPM_PATH $ISO_STAGING_PATH
    exit_on_fail "move_rpms_to_staging" $?

    # SUCCESS banner...
    output_n_chars '#' 75
    printf "#                    Repository Creation SUCCESS\n"
    printf "# \n"
    printf "# New Repo is located at: \n"
    printf "# %s\n" ${ISO_STAGING_PATH}
    output_n_chars '#' 75
}

#########################################
#########################################
###
###            BASH 'Main'
###
#########################################
#########################################

declare -A array ARG_DEFS
ARG_DEFS['baseurl']='mandatory,multi,nolist'
ARG_DEFS['iso-in']='mandatory,single,nolist'
ARG_DEFS['iso-out']='mandatory,single,nolist'
ARG_DEFS['workspace']='mandatory,single,nolist'
ARG_DEFS['pkglist']='mandatory,multi,list'
ARG_DEFS['pkgdel']='mandatory,multi,list'
ARG_DEFS['pkglast']='mandatory,multi,list'
ARG_DEFS['iso.vol']='mandatory,single,nolist'
ARG_DEFS['iso.volset']='mandatory,single,nolist'
ARG_DEFS['iso.app']='mandatory,single,nolist'
ARG_DEFS['os-version']='mandatory,single,nolist'
ARG_DEFS['yum-conf']='mandatory,single,nolist'
ARG_DEFS['ks-file']='mandatory,single,nolist'
ARG_DEFS['misc-file']='mandatory,multi,list'
ARG_DEFS['template']='mandatory,multi,list'
ARG_DEFS['pkgdir']='mandatory,single,nolist'
ARG_DEFS['config']='mandatory,single,nolist'
ARG_DEFS['config-path']='mandatory,single,nolist'
ARG_DEFS['rsync-opts']='mandatory,multi,list'
ARG_DEFS['misc-url']='mandatory,multi,list'
ARG_DEFS['yum_extra_args']='mandatory,multi,list'
ARG_DEFS['prompt-for-tools']='mandatory,single,nolist'
ARG_DEFS['rpm-to-iso-pattern']='mandatory,single,nolist'

declare -A array ARG_HELP
ARG_HELP['baseurl']='Add repo URL to generate a dscrete /etc/yum.conf from invoking host'
ARG_HELP['iso-in']='Path to ISO image to use as source'
ARG_HELP['iso-out']='Path for output ISO image'
ARG_HELP['workspace']='Path to Workspace'
ARG_HELP['pkglist']='List of packages/groups to install'
ARG_HELP['pkgdel']='Package Prefixes to delete before last install'
ARG_HELP['pkglast']='Package prefixes to include last'
ARG_HELP['iso.vol']='ISO volume label'
ARG_HELP['iso.volset']='ISO volume group name'
ARG_HELP['iso.app']='ISO Authoring Application name (string)'
ARG_HELP['os-version']='OS Version e.g. 7 for CentOS 7.3'
ARG_HELP['yum-conf']='Path to user-specified yum.conf file (not compatible with baseurl)'
ARG_HELP['ks-file']='location of source kickstart file'
ARG_HELP['misc-file']='<source-file>,<dest-file>'
ARG_HELP['template']='<source-template>,<dest file>'
ARG_HELP['pkgdir']='packages directory name for ISO (e.g. Packages)'
ARG_HELP['config']='mkiso configuration file'
ARG_HELP['config-path']='additional configuration files path'
ARG_HELP['rsync-opts']='options to rsync... e.g. --exclude <dir>'
ARG_HELP['misc-url']='file URL added to ISO rootdir, e.g. http://files.128technology.com/filename'
ARG_DEFS['yum_extra_args']='Extra arguments to add to yum operations...'
ARG_DEFS['prompt-for-tools']='Prompt before installing ISO tools locally (yes/no)'
ARG_DEFS['rpm-to-iso-pattern']='Regex to obtain iso name from matching package'

declare -A MKISO_VALS

MKISO_INVOKED_PATH=${PWD}
MKISO_EXEC_PATH=`dirname $0`
if [[ ${MKISO_EXEC_PATH:0:1} == "." ]] ; then
    MKISO_EXEC_PATH=${MKISO_INVOKED_PATH}
fi
if [[ ${MKISO_EXEC_PATH:0:1} != "/" ]] ; then
    MKISO_EXEC_PATH=${MKISO_INVOKED_PATH}/${MKISO_EXEC_PATH}
fi
MKISO_DEFAULT_PATH=${MKISO_INVOKED_PATH}
echo "INVOKED FROM: ${MKISO_INVOKED_PATH}"
echo "EXEC PATH:    ${MKISO_EXEC_PATH}"
echo "DFLT PATH:    ${MKISO_DEFAULT_PATH}"

check_bash_version '4.2'
exit_on_fail "check_bash_version" $?

process_command $@
exit_on_fail "process_command" $?

exit 0
