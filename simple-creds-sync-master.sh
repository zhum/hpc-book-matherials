#!/usr/bin/env bash
#
#  Just an example, use clush or pdsh instead
#

TIMEOUT=600  # overall script timeout
CT=3         # node connect timeout

# exit the script after getting ALRM signal
trap 'exit' ALRM

# schedule ALRM signal to self
(sleep $TIMEOUT && kill -ALRM "$$") &

# do the sync! (sequential)
for i in $(grep -v \# /etc/nodes); do
  ssh -o connecttimeout=$CT $i /usr/sbin/master-sync
  echo -n .
  sleep 0.1
done
echo "done"

