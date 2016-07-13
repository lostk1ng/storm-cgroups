#!/bin/sh

CGROUP_STATUS_FILE="/proc/cgroups"

# check if cgroups is supported
if [ ! -f "$CGROUP_STATUS_FILE" ]; then
	echo "cgroups not supported!"
	exit 0
fi

# check cpu subsys mount point
CGROUP_CPU_PATH=`lssubsys -m cpu | awk '{print $2}'`
if [ -z "$CGROUP_CPU_PATH" ]; then
	# if no mount point, means no cgroup avialable
	echo "no cgroup to clear!"
	exit 0
fi


echo "---------`date '+%Y-%m-%d %H:%M:%S'`---------clear start-----------------"
echo "CGROUP_CPU_PATH:$CGROUP_CPU_PATH"


# get all worker pid, and add them to root cgroup's cgroup.procs file in order to remove them from storm cgroup
# the no-longer-usered storm cgroups will be automatically removed from cgroup by using release_agent
echo "---------`date '+%Y-%m-%d %H:%M:%S'`--------------clear loop--------------"
worker_pids=`ps aux | grep java | grep 'backtype.storm.daemon.worker' | awk '{print $2}'`
for pid in $worker_pids; do
	echo "$pid" > "$CGROUP_CPU_PATH/cgroup.procs"
	echo "clear pid:$pid to $CGROUP_CPU_PATH/cgroup.procs"
done

echo "---------`date '+%Y-%m-%d %H:%M:%S'`---------clear done-----------------"

exit 0

