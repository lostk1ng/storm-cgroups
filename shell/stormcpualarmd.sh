#!/bin/sh


function help_msg() {
    echo "Usage: stormcpualarmd.sh <ALARM_THRESHOLD>"
    echo "                          ALARM_THRESHOLD: the percentage nr_throttled/nr_periods during a period of time, [50, 100]"
}


CGROUP_STATUS_FILE="/proc/cgroups"
ALARM_THRESHOLD=80


if [ $# -gt 1 ]; then
    help_msg
    exit 0
fi


if [ $# -eq 1 ]; then
    if [ $1 -ge 50 -a $1 -le 100 ]; then
        ALARM_THRESHOLD=$1
    else
        help_msg
        exit 0
    fi
fi


# check if cgroups is supported
if [ ! -f "$CGROUP_STATUS_FILE" ]; then
    echo "cgroups not supported!"
    exit 0
fi


# check cpu subsys mount point
CGROUP_CPU_PATH=`lssubsys -m cpu | awk '{print $2}'`
if [ -z "$CGROUP_CPU_PATH" ]; then
    echo "no cpu mount point find!"
    exit 0
fi


# check weibo_storm controll group
CGROUP_CPU_STORM_PATH="$CGROUP_CPU_PATH/weibo_storm"
if [ ! -d "$CGROUP_CPU_STORM_PATH" ]; then
    echo "no weibo_storm cgroup find!"
    exit 0
fi


# check cpu stat file for active cpu alarm
# cpu_stat_file content:
#    pid-$pid1 last_nr_periods last_nr_throttled
#    pid-$pid2 last_nr_periods last_nr_throttled
#    pid-$pid3 last_nr_periods last_nr_throttled

CPU_STAT_FILE="$(dirname $0)/cpu_stat_file"
if [ ! -f "$CPU_STAT_FILE" ]; then
    touch "$CPU_STAT_FILE"
fi


echo "---------`date '+%Y-%m-%d %H:%M:%S'`---------cpu alarm daemon start-----------------"
echo "CGROUP_CPU_PATH:$CGROUP_CPU_PATH"
echo "CGROUP_CPU_STORM_PATH:$CGROUP_CPU_STORM_PATH"
echo "ALARM_THRESHOLD:$ALARM_THRESHOLD"
echo "CPU_STAT_FILE:$CPU_STAT_FILE"



CPU_STAT_TMP_ARRAY=()
echo "---------`date '+%Y-%m-%d %H:%M:%S'`--------------cpu alarm loop--------------"
worker_pids=`ps aux | grep java | grep 'backtype.storm.daemon.worker' | awk '{print $2}'`
for pid in $worker_pids; do
    CGROUP_CPU_STORM_WORKER_CPU_STAT="$CGROUP_CPU_STORM_PATH/local-worker-pid-$pid/cpu.stat"
    if [ ! -f "$CGROUP_CPU_STORM_WORKER_CPU_STAT" ]; then
        echo "no worker cgroup find at: $CGROUP_CPU_STORM_WORKER_CPU_STAT"
    else
        now_nr_periods=`grep 'nr_periods' "$CGROUP_CPU_STORM_WORKER_CPU_STAT" | awk '{print $2}'`
        now_nr_throttled=`grep 'nr_throttled' "$CGROUP_CPU_STORM_WORKER_CPU_STAT" | awk '{print $2}'`
        last_nr_periods=`grep pid-$pid $CPU_STAT_FILE | awk '{print $2}'`
        last_nr_throttled=`grep pid-$pid $CPU_STAT_FILE | awk '{print $3}'`

        if [ ! -z "$now_nr_periods" ] && [ ! -z "$now_nr_throttled" ]; then
            if [ ! -z "$last_nr_periods" ] && [ ! -z "$last_nr_throttled" ]; then
                nr_periods=$(($now_nr_periods-$last_nr_periods))
                nr_throttled=$(($now_nr_throttled-$last_nr_throttled))
                if [ $nr_periods -gt 0 -a $nr_throttled -ge 0 -a $nr_throttled -le $nr_periods ]; then
                    throttled_percentage=$(($nr_throttled*100/$nr_periods))
                    if [ $throttled_percentage -ge $ALARM_THRESHOLD ]; then
                        #alarm
                        topologyname=`ps aux | grep $pid | grep 'backtype.storm.daemon.worker' | awk -F'backtype.storm.daemon.worker ' '{print $2}' | awk '{print $1}'`
                        echo "[ALARM] pid:$pid,nr_throttled:$nr_throttled,nr_periods:$nr_periods,throttled_percentage:$throttled_percentage,topologyname:$topologyname"
                    else
                        echo "[NORMOL] pid:$pid, nr_throttled:$nr_throttled, nr_periods:$nr_periods, throttled_percentage:$throttled_percentage"
                    fi
                fi
            fi
            # add to CPU_STAT_TMP_ARRAY
            CPU_STAT_TMP_ARRAY[${#CPU_STAT_TMP_ARRAY[@]}]="pid-$pid $now_nr_periods $now_nr_throttled"
        fi
    fi

done

# update cpu_stat_file
> "$CPU_STAT_FILE"
for i in "${!CPU_STAT_TMP_ARRAY[@]}"; do
    echo "${CPU_STAT_TMP_ARRAY[$i]}" >> "$CPU_STAT_FILE"
done

exit 0

