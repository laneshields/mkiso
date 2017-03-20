+--------------------------------------------------------------------------
|              _    _                _     
|     _ __ ___ | | _(_)___  ___   ___| |__  
|    | '_ ` _ \| |/ / / __|/ _ \ / __| '_ \ 
|    | | | | | |   <| \__ \ (_) |\__ \ | | |
|    |_| |_| |_|_|\_\_|___/\___(_)___/_| |_|
|
|    ISO Builder script 
|
|    Documentation Version 0.1
|
+---------------------------------------------------------------------------

Introduction:

mkiso.sh --config=myconfig.cfg --iso-in=/path/to/CentOS-Mnimal-1611.iso


Commands
Base Paths
Filenames
Template Variables
Package Lists

Commands
=======

o create
 
Create an ISO including packages, package groups, and all resolved dependencies

o show

Lists Parameters without perfroming any operations

o test

Test installation of packages using an ISO source

Parameters:
===========
There are many different parameters which control what where and how various inputs are
transformed, copied and staged in order to create the target ISO file.  In general,
User command line parameters are preferred over arguments specified in a config-file.
config-file arguments are preferred over basic default hard-coded into the script.

       User Command Line Arguments
                    |
                    V
 MKISO Configuration File (--mkiso-cfg=<path>)
                    |
                    V
         Hard-coded Default values

Although the tool may be completely controlled by command-line parameters, 
It is unlikely that anyone would have the patience to type (or hope their shell
histoy retained) the 10 plus arguments which night be necessay to completely
customize the tool's behavior.  Thus it is strongly suggested a configuration file
(by default named mkiso.cfg) be used.

The default path for the configuration file is the current working directory from where
the script is invoked, but this can be overidden (from the command line only) using the
mkiso-cfg parameter. e.g. mkiso --mkiso-cfg=$HOME/isofun/myiso.cfg

Arguments may be:
-singleton (only one instance allowed with one value)
-multiple (multiple instances and/or lists allowed)
-novalue (only once instance with no value; a flag)

All parameters available to the config file are available  via the command line using
similar syntax:

Singleton command-line:
  --paremeter=value
Singleton config-file:
  parameter=value
Multiple command-line:
  --parameter-1=value --parameter-2=value ... --parameter-n={value value ... value}
Multiple config-file:
  parameter-1=value
  parameter-2=value 
         :
  parameter-n={value value ... value}
Novalue command-line:
  --parameter
Novalue config-file:
  parameter

Note that the parameter and value must be seperated by '=' only as use of whitespace
complicates command-line argument parsing.

Lists:
  As BASH has difficulties in dealing spaces used in too many contexts, specific
  characters are used to delimit lists of items:
  { - opens a list
  } - closes a list

  - Lists are not allowed within lists
  - List items are separated by spaces
  - List delimeters are not allowed to be seperated from list items by spaces
    (i.e. --parameter={ value... or --paremeter={value value } is not permitted).
    --parameter= { is not accepted either.

Specifiying Package Lists:
==========================
Packet lists are used for 2 purposes:
1) To tell yum what packages to download
2) To populate the kickstart file with rpms to install (unless specifcally overidden by 
   a prefix... see prefixes, below)

Package list Formatting:
------------------------
CommandLine:
--pkglist=<pkg-spec> ... --pkglist={pkg-spec-1 pkg-spec-2 ... pkg-spec-n} ...

Configuration File:
pkglist=<pkg-spec>
pkglist={<pkg-spec-1> <pkg-spec-2> ... <pkg-spec-n>}


In general packages are specifed uing the latest yum/kickstart syntax:
--pkglist=128T 

Package List Prefixes:
----------------------
+              Used for RPM files. Copies rpm file to RPM download area so is it included 
                   In the RPMs copied to the iso-staging area:
		   Example: --pkglist=+/path/to/my/file.rpm

-              Prevents the package / group from being included in the kickstart file.  This
	           is usually only used with @base in my experience.
		   Example: --pkglist=-@base

~              Searches for and use the latest <name>*.rpm file as a package source.
	           Example: --pkglist=~128T-3.0.0

WARNING: The following is experimental as kickstart files may not support whitespace
         separated package group names!!!! Use at your own risk.

'group name'   In my experience yum install only suports the single-word package group names.
                   For example @^minimal, but not 'Minimal Install'.  If a packge name is
		   is enclosed in quotes, it will be resolved with yum groupinstall versus
                   yum install.

When packages are added to the kickstart file, package groups are automatically
moved to the beginning of the list of packages to be installed.

Additional Package Parameters
-----------------------------
These parameters were added to allow for later packages than currently allowed by
a dependent package to be removed before the rpm was mock-installed to gather dependent
pakage.   In short this is a quick way to avoid determining which kernel to make the grub2 
default using grub2-set-default to set a kernel gleaned from reqoquery --requires --recurse 
--resolve...

--pkgdel
A multi-list of package prefixes to delete (using the bash glob syntax) after the first 
pass of package intsallation.

Example:
--pkgdel={foo bar}

mkiso.sh would perform rm -f foo*.rpm bar*.rpm in the workspace tum_rpm_download area
prior to executing the second pass of RPM mock-installs

--pkglast
Specifies patterns of package names (RPMs) to defer gathering for until the second
mock-install pass (after --pkgdel patterns are deleted)

Example:
--pkglist={-@base @core foo bar}
--pkglast={foo bar}

Any RPM package regex matching foo or bar (This is different matching than used for 
--pkgdel), would be mock-installed after both the first mock-install pass (of @base and 
@core) and the package deletion step (driven by the --pkgdel parameter).

Another Example:
--pkglist={@core -@base lshw ipmi-tools salt-minion}
--pkgdel={ipmi-tools}
--pkglast={salt-minion}

1) @core, @base lshw are mock-installed by yum
2) all ipmi-tools*.rpm files are removed from the yum rpm download area
3) salt-minion package is mock-stalled


KickStart File Processing
=========================
KickStart files are always copied to the root of the iso-staging area in the 
mkiso workspace dirctory (./mksio-work-space/iso-staging by default). Unlike other
files, the destination of this file cannot be changed.

Note that the package specification area (the section between %packages and %end)
is overwritten by the mkiso script, so any packages or groups specified in
the source file will be missing from the target unless they are specified in the
--pkglist parameter.

The path to the source kickstart file may be specified using the --ks-file=/path/to/ks.cfg
parameter and value.

The default source kickstart file is determined by the --config-path parameter 
plus a default name of 128T-ks.cfg.

If a source directory is specified instead of a file, the default name of 128T-ks.cfg
will be added to the pathname.

If -ks-file is provided but does not start with '/', then the --config-path parameter
will be prepended.

Miscellaneous File processing
=============================
Miscellaneous files can be copied from the configuration area to anywhere in the
iso-staging area.  These files are copied without modification.

--misc-file=<src-path>,<dest-path> ...  --misc-file=<src-path>,<dst-path> ...

or

--misc-file=<src-path>

o If a dest-path is not present, a default target of the iso-staging root is used
o If a dest filename is not specified, the filename (not the full path) specified 
  in the source will be used
o If the source path does not start with '/' the configuration path defined by the
  --config-path parameter will be applied.

Templated File Processing
=========================


{{ ISO_VOLUME_NAME }} => --iso.volume_name=FUBAR 
{{ ISO_YOUR_VARIABLE }} => --iso.your_variable={This is how a multi-word value can be entered}


Configuration File Example:
==========================
pkglist={128T @base @core lshw salt-minion}
# Yum requires an OS version...
os-version=7

# Files copied w/o change (not templated) 
# the default target is the staging area root
misc-file=ifcfg-mgmt
misc-file=ifcfg-dpX
misc-file=128t-scripts.zip
misc-file=128t-splash.png,isolinux/128t-splash.png

# Kickstart is not normally a templated file and always 
# has a target of the staging area root.  kickstart can
# be templated
ks-file=128T-ks.cfg

# Templated variable values
iso-vol=128T
iso-volgrp=128T_GRP
iso.boot_timeout=15
iso.linux_timeout=150
iso.linux_backround=128t-splash.png

# The default target for templated files is
# the staging area root...
template=efi-grub.cfg,EFI/BOOT/grub.cfg

template=isolinux.cfg,isolinux/isolinux.cfg
# where to find templates and misc files
config-path=128t-iso

