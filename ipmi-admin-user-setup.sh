#!/usr/bin/env bash
#
# Setup admin access for ipmi channel
#

USERNAME=adminuser
USERINDEX=3
CHANNEL=1
PASSWORD=CHANGE_THIS_PASSWORD
UPDATED=false

if [ $UPDATED != true ]; then
    echo "Please, update variables in the script head!"
    exit 1
fi

ipmitool user set name $USERINDEX $USERNAME
ipmitool user set password $USERINDEX $PASSWORD
ipmitool user priv $USERINDEX 4 $CHANNEL

ipmitool lan set $CHANNEL access on
ipmitool lan set $CHANNEL auth admin md5
ipmitool channel setaccess $CHANNEL $USERINDEX privilege=4
ipmitool sol payload enable $CHANNEL $USERINDEX
ipmitool sol set enabled true 
