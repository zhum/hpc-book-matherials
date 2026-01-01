#!/usr/bin/env bash

ups_addr=${1:-localhost}

# SNMP command that retrieves the internal temperature of the UPS.
inttempcmd=".1.3.6.1.4.1.318.1.1.1.2.2.2.0"
# SNMP command that receives data from an external sensor.
ambtempcmd="1.3.6.1.4.1.318.1.1.10.2.3.2.1.4.0"
# Function that sends a request to the UPS
function sendcmd(){
  host=$1
  cmd=$2
  res=$(snmpget -c public -v 2c $host $cmd | awk -F: '{print $4}')
  echo $res
}
tempamb=$(sendcmd $ups_addr $ambtempcmd)

echo $tempamb

