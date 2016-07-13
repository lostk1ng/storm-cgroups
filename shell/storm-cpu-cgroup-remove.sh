#!/bin/sh

# auto remove worker cgroup trrigered by release_agent and notify_on_release
CGROUP_CPU_PATH=`lssubsys -m cpu | awk '{print $2}'`
if [ ! -z "$CGROUP_CPU_PATH" ] && [ ! -z "$1" ] && [ -d "$CGROUP_CPU_PATH$1" ]; then
	rmdir "$CGROUP_CPU_PATH$1"
fi
