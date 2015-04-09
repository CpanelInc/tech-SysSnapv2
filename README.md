Sys-snap logs resource usage to help troubleshoot load issues. Sys-snap logs data using these tools at one minute increments:
```
- /proc/loadavg
- /proc/meminfo
- mstat 1 10
- ps auwwxf
- netstat -anp
- mysqladmin proc
- localhost/whm-server-status
- http://localhost/server-status
- lsof
```

Logs are stored in '/root/system-snapshot'. Log size varies depending on the number of users and processes running. Small to medium servers will use about 50-250MB of storage.

You can download the script to the '/root' directory by running this command:
```
wget -O /root/sys-snap.pl https://raw.githubusercontent.com/cPanelTechs/SysSnapv2/master/sys-snap.pl
```

To start start sys-snap using this command. It will ask for confirmation to start:
```
cd /root/ && chmod 744 sys-snap.pl && perl sys-snap.pl --start
```

Sys-snap will run in the background. Logs will be written to /root/sys-snapshot/ every minute. Every hour a new folder with the current hour will be created. After 24 hours the folder should look like this:
***
<pre>
root@server[/root/system-snapshot]# ls
./  ../  0/  1/  10/  11/  12/  13/  14/  15/  16/  17/  18/  19/  2/  20/  21/  22/  23/  3/  4/  5/  6/  7/  8/  9/  current@
</pre>
***

Each hour will have logs that were created for every minute of the hour:
***
<pre>
root@server[/root/system-snapshot/0]# ls
./     10.log  13.log  16.log  19.log  21.log  24.log  27.log  2.log   32.log  35.log  38.log  40.log  43.log  46.log  49.log  51.log  54.log  57.log  5.log  8.log
../    11.log  14.log  17.log  1.log   22.log  25.log  28.log  30.log  33.log  36.log  39.log  41.log  44.log  47.log  4.log   52.log  55.log  58.log  6.log  9.log
0.log  12.log  15.log  18.log  20.log  23.log  26.log  29.log  31.log  34.log  37.log  3.log   42.log  45.log  48.log  50.log  53.log  56.log  59.log  7.log
</pre>
***

After 24 hours the logs will start to overwrite the previous logs. Each minute will overwrite the oldest log file. The logs are based on 24 hour time. 0 is 12AM.

Sys-snap can print the CPU and Memory of users for a time range. To print the basic resource usage for a time range, use the '--print' parameter along with a start and end time. This command will print the basic usage from 1AM to 2AM:

This command will need to be run in the same directory 'sys-snap.pl' was downloaded to:
```
perl sys-snap.pl --print 1:00 2:00
```

Example output from the above command.
***
<pre>
user: root
        cpu-score: 88.70
        memory-score: 80.50

user: munin
        cpu-score: 56.30
        memory-score: 7.70

user: dovecot
        cpu-score: 0.40
        memory-score: 2.30

user: mailnull
        cpu-score: 0.00
        memory-score: 0.00

user: nobody
        cpu-score: 0.00
        memory-score: 168.10

user: mysql
        cpu-score: 0.00
        memory-score: 28.80

user: named
        cpu-score: 0.00
        memory-score: 2.50

user: mailman
        cpu-score: 0.00
        memory-score: 48.80

user: sshd
        cpu-score: 0.00
        memory-score: 0.00

user: dovenull
        cpu-score: 0.00
        memory-score: 13.30
</pre>
***

This list will be sorted by per user CPU usage, with the CPU and Memory usage they had during the time range. A larger score indicates larger resource usage. Many Apache processes will run as the 'nobody' user.

To print the processes each user was running during that time, add the 'v' or '--v' flag.
```
perl sys-snap.pl --print 1:00 2:00 v
```

Example output from the above command:
***
<pre>
user: munin
	cpu-score: 106.40
		C: 59.90 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-update
		C: 21.00 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-limits
		C: 17.00 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-graph --cron
		C: 8.00 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-html
		C: 0.50 proc: \_ /usr/local/cpanel/3rdparty/share/munin/munin-update [Munin::Master::UpdateWorker<server.com;host.server.com>]
		C: 0.00 proc: \_ /bin/sh /usr/local/cpanel/3rdparty/perl/514/bin/munin-cron
	memory-score: 6.70        memory-score:
		M: 3.30 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-update
		M: 1.80 proc: \_ /usr/local/cpanel/3rdparty/share/munin/munin-update [Munin::Master::UpdateWorker<server.com;host.server.com>]
		M: 0.70 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-limits
		M: 0.60 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-graph --cron
		M: 0.30 proc: \_ /usr/local/cpanel/3rdparty/perl/514/bin/perl /usr/local/cpanel/3rdparty/share/munin/munin-html
		M: 0.00 proc: \_ /bin/sh /usr/local/cpanel/3rdparty/perl/514/bin/munin-cron
user: dovecot
	cpu-score: 6.90
		C: 6.90 proc: \_ dovecot/auth
		C: 0.00 proc: \_ dovecot/anvil

	memory-score: 84.30       memory-score:
		M: 84.30 proc: \_ dovecot/auth
		M: 0.00 proc: \_ dovecot/anvil
</pre>
***

You can remove the cpu or memory output from the verbose --print output by using '--no-cpu' or '--no-memory'.
```
perl sys-snap.pl --print 1:00 2:00 v --no-cpu
```

If you want to limit the number of lines under each CPU and memory section, use the '--max-lines' flag.
```
perl sys-snap.pl --print 1:00 2:00 v --max-lines=10
```

This command will check if sys-snap is running.
```
perl sys-snap.pl --check
```

To stop sys-snap run this from the directory sys-snap.pl was downloaded to. It will ask for confirmatino to stop the process.
```
perl sys-snap.pl --stop
```

To print load information for an interval use '--loadavg time1 time2'.
***
<pre>
perl sys-snap.pl --loadavg 1:00 2:00

Time    1min-avg        5min-avg        15min-avg
1:00    0.00            0.02            0.02
1:10    0.01            0.04            0.04
1:20    0.06            0.15            0.08
1:30    0.14            0.04            0.02
1:40    0.06            0.03            0.02
1:50    0.00            0.02            0.00
2:00    0.31            0.09            0.02
</pre>
***

By default --loadavg prints load information in 10 minute increments. You can change this from 1-60 minutes using '--i'.
```
perl sys-snap.pl --loadavg 1:00 2:00 --i=5
```

You can also use the 'sar' command to determin high load intervals which need to be looked at in closer detail.
Output from the 'sar' command:
***
<pre>
Linux 2.6 (host.server.com)    01/02/2101      _x86_64_        (24 CPU)

12:00:02 AM     CPU     %user     %nice   %system   %iowait    %steal     %idle
12:10:02 AM     all      0.38      0.29      0.17      0.01      0.04     99.11
12:20:02 AM     all      0.91      0.30      0.24      0.02      0.05     98.49
12:30:02 AM     all      4.03      0.32      0.71      0.15      0.10     94.69
12:40:02 AM     all     35.99      0.31     20.33      0.73      0.26     50.34
12:50:01 AM     all     75.40      0.27     30.17      1.01      0.04     00.12
01:00:02 AM     all     55.38      0.33     25.16      0.90      0.02     20.10
01:10:01 AM     all      0.41      0.30      0.17      0.01      0.05     99.06
01:20:01 AM     all      0.39      1.29      0.29      0.13      0.05     97.84
</pre>
***

In this case, to show detailed usage about a key interval above:
```
perl sys-snap.pl --print 00:30 1:10 v
```

More information about 'sar' and sysstat here:
http://man7.org/linux/man-pages/man5/sysstat.5.html
