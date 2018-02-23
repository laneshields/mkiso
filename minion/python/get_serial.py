#!/usr/bin/python
import re
import lshw

gBadExprs=[]
gBadExprs.append('0')
gBadExprs.append('to be filled by O.E.M.')

# Retrieve serial number.  Converto to Lower Case
serno=lshw.get_serial_number().lower()

if serno != '':
    for expr in gBadExprs:
        if re.match(expr, serno, re.IGNORECASE):
            serno=''
            break

# If no serial number is extracted, defaults to a MAC
# Converto to Lower Case
if serno == '':   
    serno=lshw.get_first_intf_mac()
    serno=re.sub(':', '', serno)
    serno='MAC' + serno
    serno=serno.lower()
print "%s" % serno
