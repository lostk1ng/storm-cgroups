#!/bin/sh

function help_msg() {
	echo "Usage: stormcpud.sh <cpu_max_usage_percentage_for_each_worker>"
	echo "                    cpu_max_usage_percentage_for_each_worker: integer range [10,90] or -1(means no limit), default to 50"
}


if [ $# -gt 1 ]; then
	help_msg
	exit 0
fi

# get cpu_max_usage_percentage_for_each_worker
CPU_MAX_USEAGE_PERCENTAGE=50
if [ $# -eq 1 ]; then
	if [ $1 -ge 10 -a $1 -le 90 -o $1 -eq -1 ]; then
		CPU_MAX_USEAGE_PERCENTAGE=$1
	else
		help_msg
		exit 0
	fi
fi


CGROUP_STATUS_FILE="/proc/cgroups"
DEFAULT_CGROUP_CPU_PATH="/cgroup/cpu"


# check if cgroups is supported
if [ ! -f "$CGROUP_STATUS_FILE" ]; then
	echo "cgroups not supported!"
	exit 0
fi

# check storm-cpu-cgroup-remove.sh
REMOVE_SHELL_PATH="$(dirname $0)/storm-cpu-cgroup-remove.sh"
if [ ! -x "$REMOVE_SHELL_PATH" ]; then
	echo "no storm-cpu-cgroup-remove.sh found at path: $REMOVE_SHELL_PATH"
	exit 0
fi


# check cpu subsys mount point
CGROUP_CPU_PATH=`lssubsys -m cpu | awk '{print $2}'`
if [ -z "$CGROUP_CPU_PATH" ]; then
	# if no mount point, then mount cpu subsys at default path
	rm -rf "$DEFAULT_CGROUP_CPU_PATH"
	mkdir -p "$DEFAULT_CGROUP_CPU_PATH"
	mount -t cgroup -o cpu cpu "$DEFAULT_CGROUP_CPU_PATH"
	CGROUP_CPU_PATH="$DEFAULT_CGROUP_CPU_PATH"
fi

# set cpu root release_agent content to REMOVE_SHELL_PATH for auto remove unused storm worker controll group
echo $REMOVE_SHELL_PATH > "$CGROUP_CPU_PATH/release_agent"


# check weibo_storm controll group
CGROUP_CPU_STORM_PATH="$CGROUP_CPU_PATH/weibo_storm"
if [ ! -d "$CGROUP_CPU_STORM_PATH" ]; then
	mkdir "$CGROUP_CPU_STORM_PATH"
fi


# get logic cpu number
LOGIC_CPU_NUM=`cat /proc/cpuinfo | grep processor | wc -l`
# calulate max cpu usage percentage for each worker lanched at supervisor
CPU_CFS_PERIOD_US_VALUE=100000
CPU_CFS_QUOTA_US_VALUE=$(($LOGIC_CPU_NUM*$CPU_CFS_PERIOD_US_VALUE*$CPU_MAX_USEAGE_PERCENTAGE/100))
if [ $CPU_CFS_QUOTA_US_VALUE -le 0 ]; then
	CPU_CFS_QUOTA_US_VALUE=-1 # avoid exception, -1 means no limit to cpu usage
fi

# weibo_storm root config
echo $CPU_CFS_PERIOD_US_VALUE > "$CGROUP_CPU_STORM_PATH/cpu.cfs_period_us"
echo -1 > "$CGROUP_CPU_STORM_PATH/cpu.cfs_quota_us" # no limit to cpu max useage


echo "---------`date '+%Y-%m-%d %H:%M:%S'`---------daemon start-----------------"
echo "CGROUP_CPU_PATH:$CGROUP_CPU_PATH"
echo "CGROUP_CPU_STORM_PATH:$CGROUP_CPU_STORM_PATH"
echo "LOGIC_CPU_NUM:$LOGIC_CPU_NUM"
echo "CPU_MAX_USEAGE_PERCENTAGE:$CPU_MAX_USEAGE_PERCENTAGE"
echo "cpu.cfs_period_us:$CPU_CFS_PERIOD_US_VALUE"
echo "cpu.cfs_quota_us:$CPU_CFS_QUOTA_US_VALUE"
echo "REMOVE_SHELL_PATH:$REMOVE_SHELL_PATH"


# get all worker pid at a fixed time, then add pid to corresponding worker controll group
# if a worker died, it will be automatically removed from cgroup by using release_agent
echo "---------`date '+%Y-%m-%d %H:%M:%S'`--------------guard loop--------------"
worker_pids=`ps aux | grep java | grep 'backtype.storm.daemon.worker' | awk '{print $2}'`
for pid in $worker_pids; do
	CGROUP_CPU_STORM_WORKER_PATH="$CGROUP_CPU_STORM_PATH/local-worker-pid-$pid"
	if [ ! -d "$CGROUP_CPU_STORM_WORKER_PATH" ]; then
		mkdir -p "$CGROUP_CPU_STORM_WORKER_PATH"
		echo $CPU_CFS_PERIOD_US_VALUE > "$CGROUP_CPU_STORM_WORKER_PATH/cpu.cfs_period_us"
		echo 1 > "$CGROUP_CPU_STORM_WORKER_PATH/notify_on_release" # enable trriger release_agent
	fi

	echo $CPU_CFS_QUOTA_US_VALUE > "$CGROUP_CPU_STORM_WORKER_PATH/cpu.cfs_quota_us"
	echo "$pid" > "$CGROUP_CPU_STORM_WORKER_PATH/cgroup.procs"
	echo "add pid:$pid to $CGROUP_CPU_STORM_WORKER_PATH/cgroup.procs"
done

exit 0

