#!/usr/bin/env bash
#
# Simple demo script /tmp/demo.sh
# You can try it bt adding in /etc/snmp/snmptrapd.conf line like:
#   traphandle NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatNotification /tmp/demo.sh demo-trap
# Then chmod a+x /tmp/demo.sh
# Then restart snmptrapd
# Then send test trap:
# snmptrap -v 2c -c public localhost "" \
# NET-SNMP-EXAMPLES-MIB::netSnmpExampleHeartbeatNotification \
# netSnmpExampleHeartbeatRate i 123456
#
read host
read ip
vars=

while read oid val
do
  if [ "x$vars" = "x" ]
  then
    vars="$oid = $val"
  else
    vars="$vars,\n$oid = $val"
  fi
done
echo -e "trap: $1 $host $ip $vars" > /tmp/demo.log
#
read host
read ip
vars=

while read oid val
do
  if [ "x$vars" = "x" ]
  then
    vars="$oid = $val"
  else
    vars="$vars,\n$oid = $val"
  fi
done
echo -e "Trap: $1\nHost: $host\nIP: $ip\nVARS: $vars" >> /tmp/demo.log

