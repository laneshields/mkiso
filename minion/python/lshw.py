#!/usr/bin/python
import re
import subprocess
import xml.etree.ElementTree as ET

lshw_as_xml=subprocess.check_output(['sudo', 'lshw', '-xml'])
lshw_root=ET.fromstring(lshw_as_xml)

"""
"""
def get_first_intf_mac():
    global lshw_root
    try:
        for node in lshw_root.findall(".//*[@class='network']"):
            id=''
            try:
                mac=node.find('serial').text
            except:
                pass 
            else:
 		return mac               
    except:
        return ''
    else:
        return ''

###############################################################################
###############################################################################
def run_on_intfs(func=None):
    count=0
    try:
        """
        for node in lshw_root.findall("node/node/node/node[@class='network']"):
        """
        for node in lshw_root.findall(".//*[@class='network']"):
	    id=''
            try:
                id=node.get('handle')
                """
                print (node.tag, node.attrib)
                if 'serial' not found an exception is generated...
                and the loop continues 
                """
                mac=node.find('serial').text
                func(node,count)
                count+=1
            except:
                print "Skipping %s" % id
                pass 
            else:
                pass
    except:
        return
    else:
        pass

###############################################################################
# run_on_sorted_intfs:
#
# The caller passes two functions:
# sfunc1 = network node key to add to sort list
# func1  = function to execute over nodes from sorted list
#
###############################################################################
def run_on_sorted_intfs(sfunc, func):
    count=0
    handles=[]
    handle=''
    try:
        for node in lshw_root.findall(".//*[@class='network']"):
	    id=''
            try:
                id=node.get('handle')
                mac=node.find('serial').text
                key=sfunc(node, count)
                if key != '':
                    handles.append(key)
                count+=1
            except:
                print "%d: Skipping %s" % (count, id)
                pass 
    except:
        print "%d: Bailing on findall" % count
        return
    count=0
    try:
        handles.sort()
        for handle in handles:
            xpathstr=".//*[@handle='" + handle + "']"  
            try:
                for node in lshw_root.findall(xpathstr):
                    id=node.get('handle')
                    type=node.get('class')
                    if (type != 'network'):
                        print "%d: skipping class=%s for %s" % (count, type, id)
                        continue
                    print "%d: Process %s %s" % (count, node.get('class'), id)
                    func(node, count)
                    count+=1
            except:
                print "%d: Skipping-2 %s" % (count, id)
    except:
        print "%d: Bailing on %s" % (count, handle)

###############################################################################
# run_on_sorted_intfs:
#
# The caller passes two functions:
# sfunc1 = network node key to add to sort list
# func1  = function to execute over nodes from sorted list
#
###############################################################################
def run_on_sorted_intfs_2(sfunc, func):
    count=0
    handles=[]
    handle=''
    for node in lshw_root.findall(".//*[@class='network']"):
        id=node.get('handle')
        mac=node.find('serial').text
        key=sfunc(node, count)
        if key != '':
            handles.append(key)
            count+=1

    try:
        handles.sort()
        for handle in handles:
            xpathstr=".//*[@handle='" + handle + "']"  
            try:
                for node in lshw_root.findall(xpathstr):
                    id=node.get('handle')
                    type=node.get('class')
                    if (type != 'network'):
                        print "%d: skipping class=%s for %s" % (count, type, id)
                        continue
                    print "%d: Process %s %s" % (count, node.get('class'), id)
                    func(node, count)
                    count+=1
            except:
                print "%d: Skipping-2 %s" % (count, id)
    except:
        print "%d: Bailing on %s" % (count, handle)

"""
"""
def get_serial_number():
    try:
    	for node in lshw_root.findall("node/[@class='system']"):
    	    serno=node.find('serial').text
	    break
    except:
	return ''
    else:
	return serno
