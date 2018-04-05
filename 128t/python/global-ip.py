#!/usr/bin/python
import json

# read in local-init as json and grab the data...
fin = open('/etc/128technology/local.init')
strlocal = fin.read()
fin.close()

jlocal = json.loads(strlocal)
#print "node-id: %s\n" % jlocal['init']['id']
node_id = jlocal['init']['id']

# read in global-init as json and grab the data...
fin = open('/etc/128technology/global.init')
strglobal = fin.read()
fin.close()

jlocal = json.loads(strglobal)
if node_id in jlocal['init']['control']:
    print "%s" % jlocal['init']['control'][node_id]['host']
if node_id in jlocal['init']['conductor']:
    print "%s" % jlocal['init']['conductor'][node_id]['host']
