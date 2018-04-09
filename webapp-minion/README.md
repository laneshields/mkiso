# ZTP Webapp ISO Creator
This directory contains files for creating an ISO that can be used to kick off the ZTP process.

## Overview
This is based on the original Salt minion mkiso configuration with a few changes:
- No minion configuration is written (no conductor is pre-defined)
- All interfaces found on a system will be placed into a bridge named `ztp`
- The `ztp` bridge will be assigned an address of 192.168.128.128
- The firewall settings will be restricted to only allow HTTP through
- A DHCP server will listen on the `ztp` bridge and assign addresses in the `192.168.128.0/24` network
- A lightweight webapp will be setup to listen for HTTP requests in order to set any interface addresses and the conductor IP(s)
