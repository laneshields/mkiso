#!/usr/bin/python
import re
import lshw

gBadExprs=[]
gBadExprs.append('0')
gBadExprs.append('to be filled by O.E.M.')

serno=lshw.get_serial_number()
if serno != '':
    for expr in gBadExprs:
        if re.match(expr, serno, re.IGNORECASE):
            serno=''
            break

# If no serial number is extracted, defaults to a MAC
if serno == '':   
    serno=lshw.get_first_intf_mac()
    serno=re.sub(':', '', serno)
    serno='MAC' + serno

print "%s" % serno
