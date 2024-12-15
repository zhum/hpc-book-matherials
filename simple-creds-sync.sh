#!/usr/bin/env bash
#
# Run on each cluster node, to sync credentials
# - after the server started
# - after credentials updated
#

SYNC="rsync -e 'ssh -i /root/secret_key'"
SRC_ADDR=root@master.cluster

$SYNC $SRC_ADDR:/etc/passwd /etc/passwd
$SYNC $SRC_ADDR:/etc/shadow /etc/shadow
$SYNC $SRC_ADDR:/etc/group /etc/group
$SYNC $SRC_ADDR:/etc/gshadow /etc/gshadow
