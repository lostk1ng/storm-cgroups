# Storm-CGroups

## Purpose

* Add storm worker to cpu cgroups by crontab, in order to limit the max CPU% usage for each worker in storm. When a worker process die(often trigger by kill or rebalance command), it will automatically remove the unused cgroups.
* When a worker process CPU% reach the limit, will trigger alarm.

## Code   
	.
	├── README.md
	└── shell
	    ├── storm-cpu-cgroup-clearall.sh   # clear all worker process from cgroups
	    ├── storm-cpu-cgroup-remove.sh     # if a worker died, will trigger this remove shell
	    ├── stormcpualarmd.sh              # alarm shell
	    └── stormcpud.sh                   # add worker process to cpu cgroups shell

## Deploy

* When deploy on server side, please use crontab with shell script `stormcpud.sh` and `stormcpualarmd.sh`.
* Specify Params: `stormcpud.sh` can specify max CPU% usage for each worker(default to 50%), `stormcpualarmd.sh` can specify alarm threshold(default to 80%).

## cgroup structure
	[liyan@XXXXX]$ lscgroup
	cpu:/                                       # CPU root cgroup
	cpu:/weibo_storm                            # under CPU root cgroup, will generate weibo_storm cgroup
	cpu:/weibo_storm/local-worker-pid-22341     # under weibo_storm cgroup, will generate a certain cgroup named local-worker-pid-${workerpid} for each worker process to limit cpu usage for that worker
	cpu:/weibo_storm/local-worker-pid-18547
	cpu:/weibo_storm/local-worker-pid-12848
	cpu:/weibo_storm/local-worker-pid-12063
	cpu:/weibo_storm/local-worker-pid-9842
	cpu:/weibo_storm/local-worker-pid-7559
	
## cgroups resources
1. [https://www.kernel.org/doc/Documentation/cgroups/](https://www.kernel.org/doc/Documentation/cgroups/)
2. [https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Resource_Management_Guide/index.html](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Resource_Management_Guide/index.html)
3. [http://coolshell.cn/articles/17049.html](http://coolshell.cn/articles/17049.html)
4. [http://tiewei.github.io/devops/howto-use-cgroup/](http://tiewei.github.io/devops/howto-use-cgroup/)
5. [http://www.infoq.com/cn/articles/docker-kernel-knowledge-cgroups-resource-isolation](http://www.infoq.com/cn/articles/docker-kernel-knowledge-cgroups-resource-isolation)

