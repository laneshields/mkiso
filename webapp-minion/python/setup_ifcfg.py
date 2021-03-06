#!/usr/bin/python
################################################################################
################################################################################
##
##  Setup initial network interfaces
##
##  Uses lshw xml outut to iterate over all interface nodes and apply a
##  callback function to genereate ifcfg-files
##
################################################################################
################################################################################
import os
import lshw
import re

gConfigPath='/etc/sysconfig/network-scripts'
#gConfigPath='/tmp'
gDevPrefix='ifcfg-'

gBridgeAddress='192.168.128.128'
gBridgeMask='255.255.255.0'

def config_bridge_intf():
    devname="ztp"
    fpath=gConfigPath + '/' + gDevPrefix + devname
    ifcfg_line="###############################################################################\n"
    ifcfg_line+="#\n"
    ifcfg_line+="# Interface File Generated By 128 Technology ISO Builder (mkiso)\n"
    ifcfg_line+="# Bridge for ZTP provisioning\n"
    ifcfg_line+="#\n"   
    ifcfg_line+="#\n"
    ifcfg_line+="###############################################################################\n"
    ifcfg_line += "TYPE=Bridge\n"
    ifcfg_line += "DEVICE=%s\n" % devname 
    ifcfg_line += "NAME=%s\n" % devname 
    ifcfg_line += "BOOTPROTO=none\n"
    ifcfg_line += "IPADDR=%s\n" % gBridgeAddress
    ifcfg_line += "NETMASK=%s\n" % gBridgeMask
    ifcfg_line += "ONBOOT=yes\n"
    if os.path.isfile(fpath):
        os.remove(fpath)
    fhandle = open(fpath, 'w')
    fhandle.write(ifcfg_line)
    fhandle.close()

    print "Created bridge for ZTP connectivity"


def config_wired_intf(node=None, count=0):
    mac=node.find('serial').text
    devname=node.find('logicalname').text
    pci=node.get('handle')
    fpath=gConfigPath + '/' + gDevPrefix + devname 
    ifcfg_line="###############################################################################\n"
    ifcfg_line+="#\n"
    ifcfg_line+="# Interface File Generated By 128 Technology ISO Builder (mkiso)\n"
    ifcfg_line+="# For Device-%d %s\n" % (count, pci)
    ifcfg_line+="#\n"	
    ifcfg_line+="#\n"
    ifcfg_line+="###############################################################################\n"
    ifcfg_line += "TYPE=Ethernet\n"
    ifcfg_line += "DEVICE=%s\n" % devname
    ifcfg_line += "NAME=%s\n" % devname 
    ifcfg_line += "BOOTPROTO=none\n"
    ifcfg_line += "DEFROUTE=yes\n"
    ifcfg_line += "PEERDNS=no\n"
    ifcfg_line += "PEERROUTES=no\n"
    ifcfg_line += "HWADDR=%s\n" % mac
    ifcfg_line += "ONBOOT=yes\n"
    ifcfg_line += "BRIDGE=ztp\n"
    if os.path.isfile(fpath):
        os.remove(fpath)
    fhandle = open(fpath, 'w')
    fhandle.write(ifcfg_line)
    fhandle.close()

    # print "%s" % ifcfg_line
    print "%d: Create %s for:\n\tMAC=%s %s" % (count, fpath, mac, pci)

def config_wired_interface(node=None, count=0):
    config_bridge_intf()
    config_wired_intf(node, count)

def config_wireless_interface(node=None, count=0):
    mac=node.find('serial').text
    devname=node.find('logicalname').text
    pci=node.get('handle')
    fpath=gConfigPath + '/' + gDevPrefix + devname 
    ifcfg_line="###############################################################################\n"
    ifcfg_line+="#\n"
    ifcfg_line+="# Interface File Generated By 128 Technology ISO Builder (mkiso)\n"
    ifcfg_line+="# For Wireless Device-%d %s\n" % (count, pci)
    ifcfg_line+="#\n"	
    ifcfg_line+="#\n"
    ifcfg_line+="###############################################################################\n"
    ifcfg_line += "DEVICE=%s\n" % devname
    ifcfg_line += "NAME=%s\n" % devname 
    ifcfg_line += "ONBOOT=no\n"
    ifcfg_line += "NM_CONTROLLED=no\n"
    if os.path.isfile(fpath):
        os.remove(fpath)
    fhandle = open(fpath, 'w')
    fhandle.write(ifcfg_line)
    fhandle.close()

    print "%d: Create WL %s for:\n\tMAC=%s %s" % (count, fpath, mac, pci)


def get_wired_key(node=None, count=0):
    try:
        key=node.get('handle')
        dev=node.find('logicalname').text
        if not re.match('wl', dev):
            return key
    except:
        print "skip wired candidate %d" % count
        return ''
    print "skip wired candidate %s %s" % (key, dev)
    return ''

def get_wireless_key(node=None, count=0):
    try:
        key=node.get('handle')
        dev=node.find('logicalname').text
        if re.match('wl', dev):
            return key
    except:
        print "skip wireless candidate #%d" % count
        return ''
    print "skip wireless candidate %s %s" % (key, dev)
    return ''

#
# Main 
#
lshw.run_on_sorted_intfs(get_wired_key, config_wired_interface)
lshw.run_on_sorted_intfs(get_wireless_key, config_wireless_interface)

