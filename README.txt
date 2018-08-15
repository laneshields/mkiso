+--------------------------------------------------------------------------
|               _    _                _
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
=============
mkiso.sh is a command-line tool for creating bootable Linux ISOs.

mkiso starts with a Linux distributed on an ISO.  For example,
 CentOS-7-x86_64-Minimal-1611.iso is the default, which can be acquired via
SAMBA on the corporate network if no input file is specified on the command
line or in a  configuration file.

Two commands can then be used to alter the ISO content to create a custom
installation environment:

1) mkiso.sh create
2) mkiso rpm2iso

The former relies heavily on packages and other parameters configured
in the configuration file to construct yum --installroot environment
which downloads the specified packaged and dependencies and populates a
new ISO which automatically installs (by use of an Anaconda kickstart file)
the packages requested. It also can stage a number of files, some of which can be
altered per mkiso.sh run by use of templates to further customize
the install processand its %pre and %post phases.

The latter is similar except that a file containg a list of rpms
(from rpm -qa) is used as the package list rather than configuration
or command line arguments.

One other command of note, is:
o mkiso.sh test

This command takes a ISO, generates a single ISO-based yum repository,
looks to the kickstart file for packages to install and performs a
yum install --installroot to give some degree certainty that the ISO might
actually install.


There are currently two configuraion profiles in this repository one for
a manual 128T install, an one for CentOS + a SALT minion.

Each has a configuration file and a associated directory of files:

drwxrwxr-x 2 user group   4096 Mar 23 21:59 128t (128T ISO templates and other files)
-rw-rw-r-- 1 user group   1172 Mar 24 03:24 128t.cfg (128T ISO configuration file)
drwxrwxr-x 2 user group   4096 Mar 17 19:58 minion (CentOS + minion templates and other files)
-rw-rw-r-- 1 user group   1164 Mar 17 19:55 minion.cfg (CentOS + minion ISO configuration file)
-rwxrwxr-x 1 user group 104593 Mar 25 09:29 mkiso.sh (the ISO generation tool)
-rw-rw-r-- 1 user group  16058 Mar 25 10:30 README.txt (this file)
drwxrwxr-x 2 user group   4096 Mar 25 10:37 samples (samples directory)

./128t:
total 28
-rw-r--r-- 1 user group 4017 Mar 17 19:55 128T-ks.cfg       (kick start file)
-rw-r--r-- 1 user group 1874 Mar 17 19:55 128t-scripts.zip  (scripts used by SEs)
-rw-r--r-- 1 user group 3322 Mar 23 20:21 128t-splash.png   (splash screen)
-rw-r--r-- 1 user group 1694 Mar 17 19:55 efi-grub.cfg      (grub boot menu)
-rw-r--r-- 1 user group  121 Mar 17 19:55 ifcfg-dpX         (interface config files)
-rw-r--r-- 1 user group  228 Mar 17 19:55 ifcfg-mgmt        (interface config files)
-rw-r--r-- 1 user group 3329 Mar 17 19:55 isolinux.cfg      (more boot menu config)
-rw-rw-r-- 1 user group  302 Mar 17 19:55 README.txt

./minion:
total 16
-rw-r--r-- 1 user group 1694 Mar 17 19:55 efi-grub.cfg  (grub boot menu)
-rw-r--r-- 1 user group 3321 Mar 17 19:55 isolinux.cfg  (more boot menu config)
-rw-rw-r-- 1 user group 3191 Mar 17 19:55 minion-ks.cfg (kick start file)
-rw-rw-r-- 1 user group  302 Mar 17 19:55 README.txt

./samples:
-rw-r--r-- 1 user group 12879 Mar 25 10:56 sample_rpms.txt (rpm list from rpm-qa)


+--------------------------------------------------------------------------
| Usage:
+--------------------------------------------------------------------------

Create Command:
---------------
The 'create' command is used to generate an ISO from a configuration file
which specifies which packages etc. should be installed etc. This also
specifies the kickstart, grub, and additional files to be copied to the
outut iso.  Some of these files are or can be templatized to allow for
spefific values to be used for say the title of the Anaconda Image
selection menu.

Examples:

mkiso.sh create --config=128t.cfg --iso-in=/path/to/CentOS-Minimal-1611.iso

--config=128t.cfg: config file in current directory to drive ISO generation
                   currently 128t.cfg and minion.cfg are supported

--iso-in:          Use /path/to/CentOS-Minimal-1611.iso as the ISO input file
                   to modify.

                   Use default ISO target ($PWD/mkiso-workspace/128T.iso) as
                   output

                   Where $PWD is the current working directory...

mkiso.sh create --config=128t.cfg

--config=128t.cfg: config file in current directory to drive ISO generation
                   currently 128t.cfg and minion.cfg are supported

                   Use default input ISO from corp samba mount.  You'll
                   need to enter LDAP credentials for this.

                   Use default ISO target ($HOME/mkiso-workspace/128T.iso) as
                   output

mkiso.sh create --config=128t.cfg --iso-out=/path/to/output.iso

--config=128t.cfg: config file in current directory to drive ISO generation
                   currently 128t.cfg and minion.cfg are supported

                   Use default input ISO from corp samba mount.  You'll
                   need to enter LDAP credentials for this.

--iso-out:         Use path/to/output.iso as the output iso...
                   output.  If only a filename (i.e. fubar.iso) is specified
                   then $HOME/mkiso-workspace/fubar.iso is used as the output
                   ISO.

COMMAND ${MKISO_BASE_PATH}/mkiso.sh create --config=${MKISO_BASE_PATH}/128t.cfg \\
        --config-path=${MKISO_BASE_PATH}/128t --pkglast=~${CMAKE_BINARY_DIR}/128T \\
        --iso-out=${CMAKE_BINARY_DIR} --rpm-to-iso-pattern="128T-[0-9]")

This is an exmple from a CMakefile.

--config:             Path to obtain the ISO config from.

--config-path:        Path to obtain the ISO config profile from.  This overrides the
                      config file.

--iso-out:            Use path/to/output the ISO file to.  This can also be a filename
                      but the --iso-out filename is overwritten by --rpm-to-iso-pattern
                      so it makes no difference that it would be specified.

--pkglast:            A list of packages to install after --pkglist.  This is usually
                      done so that packages matching --pkgdel can be removed before
                      --pkglist is installed.

--rpm-to-iso-pattern: A regex to match against --pkglist and --pkglast package lists
                      to find a package name to use for the output ISO filename.  The
                      .rpm extension is replaced with .iso and the path from the
                      --iso-out parameter is used (if a filename is specified in
                      --iso-out it is ignored).

NOTE: The config file in this example contains a parameter:
      iso-in=http://path/to/source/iso/file.iso.

      which causes mkiso.sh to do a wget for the input ISO.  Eventually this README should
      include more information about iso-in, iso-out etc.


test command:
------------
Tests installation of packages using an ISO source.  This command restricts
the repositories available to yum to only the repository present on the ISO,
and then invokes yum install into an installroot environment based on the
packages specified for install in the ISO's kickstart file. This does not
replace trying to boot the ISO on a VM or bare metal, as a means of validation,
but it does provide some guidance that the ISO was correctly constructed.

Examples:

mkiso.sh test --config=128t.cfg --iso-in=~/mkiso-workspace/128T.iso

--config=128t.cfg: config file in current directory to drive the test process.

--iso-in:          Use /path/to/CentOS-Minimal-1611.iso as the ISO input file
                   to attempt the yum install.

The samba mount is not available for this command as the default ISOs do
not come equipped with a kickstart file, which this script uses to
determine which packages to install.

The following parameters from the command line and/or config file are overriden:

o yum-conf  (yum parameters, because a single ISO-only repository is being used)
o yum_repo_src_conf
o yum_repo_src_path
o yum_pki_src_path
o yum_extra_args
o pkglist (package parameters because these are extracted from the kickstart file)
o pkgdel
o pkglast

rpm2iso command:
----------------
This command takes an input ISO, strips out the packages (much like create),
replaces the packages with the items specified by the file value for the
--rpm-file parameter, and generates an output iso.

The format of the --rpm-file parameter is simply a list of RPMS one can get
by issuing rpm -qa on a linux system (the OS flavor had better match the
one on the input ISO).

Examples:

mkiso.sh rpm2iso --config=128t.cfg --iso-in=/path/to/CentOS-Minimal-1611.iso
                 --rpm-file=/path/to/rpm-list-file.txt

--config=128t.cfg: config file in current directory to drive ISO generation
                   currently 128t.cfg and minion.cfg are supported

--iso-in:          Use /path/to/CentOS-Minimal-1611.iso as the ISO input file
                   to modify.

                   Use default ISO target ($PWD/mkiso-workspace/128T.iso) as
                   output

--rpm-file:        File containing explicit list of rpms generated by 'rpm -qa'


mkiso.sh rpm2iso --config=128t.cfg --rpm-file=/path/to/rpm-list-file.txt

--config=128t.cfg: config file in current directory to drive ISO generation
                   currently 128t.cfg and minion.cfg are supported

                   Use default input ISO from corp samba mount.  You'll
                   need to enter LDAP credentials for this.

                   Use default ISO target ($PWDE/mkiso-workspace/128T.iso) as
                   output

--rpm-file:        File containing explicit list of rpms generated by 'rpm -qa'


mkiso.sh rpm2iso --config=128t.cfg --iso-out=/path/to/output.iso
                   --rpm-file=/path/to/rpm-list-file.txt

--config=128t.cfg: config file in current directory to drive ISO generation
                   currently 128t.cfg and minion.cfg are supported

                   Use default input ISO from corp samba mount.  You'll
                   need to enter LDAP credentials for this.

--iso-out:         Use path/to/output.iso as the output iso...
                   output.  If only a filename (i.e. fubar.iso) is specified
                   then $HOME/mkiso-workspace/fubar.iso is used as the output
                   ISO.

--rpm-file:        File containing explicit list of rpms generated by 'rpm -qa'


show command:
-------------
This command is a mock command -- it runs through argument / parameter processing
and performs minimal error checking, but it does not create or test an ISO --
it just shows how the parameter list is populated.

repo command:
-------------
The repo command can be used to build up only the repository component of an
installation ISO.

This results in only 2 directories in the iso staging area (no others are needed):
Packages/*.rpm
repodata

Note that because the source ISO currently provides the group package definitions
xml file, no package groups will be available in the repo directory created.

These output directories could be used on a yum server as:
/var/www/repo/<repo-name>/<os-name>/<os-version>/<arch>/Packages
/var/www/repo/<repo-name>/<os-name>/<os-version>/<arch>/repodata

.repo file (normally 7 and x86_64 wold be release and arch variables):
baseurl=https://repo-server/myrepo/CentOS/7/x86_64

or locally as:

/home/user/myrepo/Packages
/home/user/myrepo/repodata

with a .repo file:
baseurl=file:///home/user/myrepo

Examples:

mkiso.sh repo --config=128t.cfg

--config=128t.cfg: config file in current directory to define parameters
                   used in repo creation.

Even though no ISO is being generated, several parameters are still needed,
including pkglist, and the iso-staging path (usually defaulted).

+-------------------------------------------------------------------------------
|
| Details.....
| ------------
| Read further if you are interested in overiding parameters or creating your
| own configuration files
+-------------------------------------------------------------------------------

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
pass of package installation.

Example:
--pkgdel={foo bar}

mkiso.sh would perform rm -f foo*.rpm bar*.rpm in the workspace tum_rpm_download area
prior to executing the second pass of RPM mock-installs

--pkglast
Specifies packages (RPMs) to defer gathering until the second mock-install pass (after
--pkgdel patterns are deleted).  This parameter has changed recently in support of
integration with build systems.

Formerly --pkglast was applied as a filter to the RPMs specified in --pkglist.  Specifying a
package in --pkglast will now cause it to be installed rather than selecting a package or
packages to install from the --pkglist parameter.  The former usage of --pkglist could
potentially result in two different instances of the same package being installed if a
similarly named RPM is present in --pkglist.

Current Example:
--pkglist={-@base @core}
--pkglast={foo bar}

Former Example:
# Remove { foo bar } from --pkglist to ensure correct functionality.
--pkglist={-@base @core foo bar}
--pkglast={foo bar}

Any RPM package regex matching foo or bar (This is different matching than used for
--pkgdel), would be mock-installed after both the first mock-install pass (of @base and
@core) and the package deletion step (driven by the --pkgdel parameter).

Another Example:
--pkglist={@core -@base lshw ipmi-tools}
--pkgdel={ipmi-tools}
--pkglast={salt-minion}

1) @core, @base lshw are mock-installed by yum
2) all ipmi-tools*.rpm files are removed from the yum rpm download area
3) salt-minion package is mock-stalled

*** New for Manifests (List of pinned package dependencies) ***
--pkgfile=<path>
Specify a path to read a list of RPMs from.  This effectively adds the RPM list to 
the --pkglist parameter.  --pkgfile overides the transform parameters specified below: 

WARNING: -- currently using --pkgfile adds all packages obtained from the 
file's package list to --pkglist in such a way that all files will be added
to the kickstart %package section.  This may or may not be desirable.  Testing with
the 128T rpm and package list has shown this to be problematic. The transform
method of obtaining additional package list content does not add additional
packages to the kickstart %packages section.  

Packge transform method
.......................
Transforms an existing package into a package name which contains the list
of additional ('pinned') rpms to install. 

The overall processs is something like:
o match an exisitng RPM
o transform it to the packe list name
o peform yum install
o save --pkglist
o extract the install file content add to --pkglist
o purge and yum cache
o perform package downloads
o use saved --pkglist to generate kickstart %packages section

The three parameters below are used in conjunction to transform one package name into
another. 

--pkg-rpm-regex="<matching-regex>"[ "<matching-regex>" .. ]

--pkg-rpm-xform="<transform>"[ "<transform>" .. ]

--pkg-rpm-skips="<matching-regex>"[ "<matching-regex>" .. ]

Also used is --pkg-rpm-path (see below)

The number of --pkg-rpm-regex parameters must match the number of --pkg-rpm-xform 
parameters.  --pkg-rpm-regex matches an rpm specified in the package list while
pkg-rpm-xform indicates how that package name can be transformed int to the
name of the package containing the rpm list.  --pkg-rpm-skips is used to gnore
packages which might otherwise match --pkg-rpm-regex.  --pkg-rpm-regex instances are
processed in sequence until a match is found. It may be helpful to think of 
--pkg-rpm-regex and --pkg-rpm-xform instances as pairs.

Note that is --pkg-rpm-file will be preferred over these parameters if it too is
specified. Double quotes are required around the expressions, which is an exception
to the normal mkiso parameter formatting rules.

The following parameters are used to transform 128T into 128T-manifest:

--pkg-rpm-regex="(.*?)128T(-[0-9]+\\.[0-9]+\\.[0-9]+)\\-(.*?)\\.x86_64"
--pkg-rpm-xform="{{1?}}128T-manifest{{2}}.{{3}}"
--pkg-rpm-regex="(.*?)128T(-)?"
--pkg-rpm-xform="{{1?}}128T-manifest{{2}}"
--pkg-rpm-skips="128T-i" 
--pkg-rpm-path=usr/lib/128T-manifest/manifest.txt

Consider 128T-3.2.5-2.el7.centos.x86_64:
pkg-rpm-regex="(.*?)128T(-[0-9]+\\.[0-9]+\\.[0-9]+)\\-(.*?)\\.x86_64":
Full match  of package name with:
matches[1]=
matches[2]=-3.5.2
matches[3]=2.el7.centos

pkg-rpm-xform="{{1?}}128T-manifest{{2}}.{{3}}":
{{1?}} -> replace with matches[1] if non-empty otherwise replace with the empty string
{{2}} -> replace wih matches[2]
{{3}} -> replace wih matches[3]

NOTE: The form {{n?}} is required to match both 128T... and /some/path/128T...

resulting in 128T-manifest-3.2.5.2.el7.centos

The second 'pair' is used to match/transform a shorter form of the package name -- 
and only if the first match fails:

Consider if only 128T was specified in the package list:
pkg-rpm-regex="(.*?)128T(-)?"
Full match  of package name with:
matches[1]=
matches[2]=

Applying the transform results in:
pkg-rpm-xform="{{1?}}128T-manifest{{2?}}"
128T-manifest

Since both matches are empty and its OK to replace the
both match specifiers in the transform with an empty
string.

--pkg-rpm-skips="128T-i" skips 128T-installer which would otherwise match the shorter
form of specifiying 128T.  Theoretically you could use -pkg-rpm-regex=(/*?)128T(-[^i])?(.*)>?
but testing showed that [^i] did not match as expected hence the reason for this parameter

--pkg-rpm-path=<path>
This is the full path to the file installed from the package derived from
--pkg-rpm-regex,--pkg-rpm-xform,--pkg-rpm-skips. This path cannot be derived
and must be expicitly specified.  This path is mandatory otherwise all of the work
to transform and install the package list is for naught.

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


WARNING: 
Using --pkgfile adds all packages obtained from the file's package list to --pkglist 
in such a way that all files will be added to the kickstart %package section.  This may or 
may not be desirable.  Testing with the 128T rpm and package list has shown this to be 
problematic. The transform method (--pkg-rpm-regex,--pkg-rpm-xform,--pkg-rpm-skips) of 
obtaining additional package list content does not add additional packages to the kickstart 
%packages section.  

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

*** New for multiple copy source paths ***

--copy-source=<src-directory>

If the source file cannot befound in the config path, additional paths can be specified
to allow common sollections of snippets and scripts.  The following rules apply:

1) copy-source paths are used only if the source file cannot be found in the config/profile
   directory
2) if a source file of the same name exists in the config profile directory AND a
   copy-source path, the config profile source is always used.
3) if a source file exists on more thn one --copy-source, this is considered an ERROR
   and ISO creation will be stopped. 
  

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



