#!/usr/bin/env bash
#
# Attention! Only for non-shared node jobs!
# For illustration purporse only
#
JOBID=$1
USER=$2

######### Get the list of task nodes ###########
if test -r "/var/spool/PBS/aux/$1"; then
   PBS_NODEFILE="/var/spool/PBS/aux/$1"
 
# Perform cleanup on each node of the task
  for node in $PBS_NODEFILE; do
  ssh -o ConnectTimeout=5 $node \
    'pkill -KILL -u $USER; \
     find /tmp -user $USER -exec rm -r \{\} \; >& /dev/null'
  done
fi

