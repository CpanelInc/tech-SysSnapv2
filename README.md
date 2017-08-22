<h1>Script details</h1>
<p>
This repo is managed by cPanel. Please submit all bugs and feature requests via email, or submit a pull request via GitHub. 
</p>
<h2>Requirements:</h2>
<ul>
<li>Root-level SSH access</li>
<li>CentOS or RedHat system</li>
</ul>
<h1>Why sys-snap?</h1>
<p>
Resource shortages can feel overwhelming and  impossible to track down without adequate data to diagnose the problem. Servers inevitably have problems when their sys-admins are not watching. While the <a href="http://documentation.cpanel.net/display/ALD/Daily+Process+Log">Daily Process Log</a> in WHM can be very helpful in these situations, sometimes more information is needed than WHM can provide.
</p>
<p>
Sys-snap is designed to help you see what is causing the resource shortages, whether CPU or Memory related, even when no one is looking. 
</p>

<p>
This version of sys-snap is specifically designed to be used via SSH by the root user on cPanel servers, which means that this documentation and application is aimed at RedHat and CentOS systems.
</p>
<h1>
<u>History of Sys-Snap</u>
</h1>
<p>
System Snapshot began at EV1 Servers in the late 1990s or early 2000s.  It was written by Mike Kroh before being extended by Nate Custer.  The script is often used when traditional methods of investigation do not shed light on what is causing servers load to skyrocket without warning or the server to crash.  Many versions of the script exist, as it has been carried by various techs to different companies who have extended and modified to fit both their general needs and specific special circumstances.  The version presented here was modified for use by employees at Hostgator and AlphaRed before being merged into a different version being used by cPanel around 2011.  A descendant of the 2011 version was ported to perl by Paul Trost at cPanel in 2013. The recent version discussed in this article was completed by Bryan Christensen at cPanel in 2015.
</p>
<h1>
How to use sys-snap
</h1>
<h2>
Install
</h2>
<p>
Sys-snap’s installation is incredibly simple two step process: Download the script, and run the install.
</p>

```
wget -O /root/sys-snap.pl https://raw.githubusercontent.com/cPanelTechs/SysSnapv2/master/sys-snap.pl && cd /root/ && chmod 744 sys-snap.pl && perl sys-snap.pl --start
```
<p>
Once installed, the script continues to run on the server until you stop it, or until the server reboots. After a reboot, if you want the script to resume recording data, you would need to start it again.
</p>
<p>
Every time you start the sys-snap.pl script, the existing data will be archived in .tar.gz format in the /root/ directory for your records.
</p>
<h2>
Starting and stopping the script
</h2>
<p>
To start the process, run the script with the --start flag:
</p>

```
[~] perl /root/sys-snap.pl --start
Sys-snap is not currently running
Start sys-snap logging to '/root/system-snapshot/' (y/n)?:y
Starting…
[~]
```
<p>
Sys-snap will run in the background. Logs will be written to /root/sys-snapshot/ every minute. Every hour a new folder with the current hour will be created. After 24 hours the folder should look similar to this:
</p>

```
[~/system-snapshot] ls -lah | head
total 104K
drwxr-xr-x  26 root root 4.0K May  5 13:50 ./
dr-xr-x---. 26 root root 4.0K May  4 22:05 ../
drwxr-xr-x   2 root root 4.0K Apr 24 00:59 0/
drwxr-xr-x   2 root root 4.0K Apr 24 01:52 1/
drwxr-xr-x   2 root root 4.0K Apr 24 10:53 10/
drwxr-xr-x   2 root root 4.0K Apr 24 11:54 11/
drwxr-xr-x   2 root root 4.0K Apr 24 12:55 12/
drwxr-xr-x   2 root root 4.0K Apr 24 13:33 13/
drwxr-xr-x   2 root root 4.0K Apr 23 14:56 14/
```
<p>
Each hour will have logs that were created for every minute of the hour:
</p>

```
[~/system-snapshot/0] ls -lah |head
total 3.5M
drwxr-xr-x  2 root root 4.0K Apr 24 00:59 ./
drwxr-xr-x 26 root root 4.0K May  5 13:51 ../
-rw-r--r--  1 root root  54K May  5 00:00 0.log
-rw-r--r--  1 root root  49K May  5 00:10 10.log
-rw-r--r--  1 root root  52K May  5 00:11 11.log
-rw-r--r--  1 root root  50K May  5 00:12 12.log
-rw-r--r--  1 root root  49K May  5 00:14 13.log
-rw-r--r--  1 root root  51K May  2 00:14 14.log
-rw-r--r--  1 root root  49K May  5 00:15 15.log
```
<p>
After 24 hours the logs will start to overwrite the previous logs. Each minute will overwrite the oldest log file. The logs are based on 24 hour time. 0 is 12AM.
</p>

<p>To stop the process, run the script with the --stop flag, and the script will ask you to confirm the process it is stopping:</p>

```
[~] perl /root/sys-snap.pl --stop
Current process: 20081 root     perl sys-snap.pl --start
Stop this process (y/n)?:y
Stopping 20081
[~]
```
<h2>
Gathering data from sys-snap
</h2>
<p>
If the load average of your server is larger than the number of processors, load issues can occur. cPanel backups, log processing, and stat processing are delayed if this happens. Tracking down the cause of the load increase is where sys-snap comes in.
</p>
<h3>
<u>Using sar to narrow your window</u>
</h3>
<p>
One utility that can be used in tandem with sys-snap to help you track and diagnose instability is called sar. To verify that the sysstat package is installed, use the command below. Please note: sysstat will only begin recording information after it is installed, and cannot provide insight for a server before the package was installed.
</p>

```
yum install -y sysstat
```
<p>
Using various flags you can display different information that has been recorded about your server’s state. In diagnosing instability, or resource shortages, using the -q and -r flags will likely be most helpful to you. Here is a small piece of output from the 'sar -q' command. The 'ldavg' is the load average. The 'ldavg-#' is the time range for the load average. The three rightmost columns represent the 1, 5, and 15 minutes load averages for the time listed in the leftmost column:
</p>

```
12:00:01 AM   runq-sz  plist-sz   ldavg-1   ldavg-5  ldavg-15
...
06:10:01 AM      7    107   1.22   1.19   0.76
06:20:01 AM      5    104   1.31   0.99   0.83
06:30:01 AM     26    151  21.11  13.58   6.76
06:40:11 AM      7    158  21.74  20.63  13.96
06:50:02 AM     25    146  22.29  21.95  17.84
07:00:01 AM     24    148  23.46  23.35  20.46
07:10:02 AM     24    138  23.50  23.05  21.56
07:20:01 AM     23    142  19.20  20.36  20.91
07:30:01 AM     17    135  14.67  16.01  18.45
07:40:01 AM      7    103   1.70   8.44  14.09
07:50:01 AM      4    103   0.06   1.49   7.66
08:00:01 AM      4    105   0.01   0.23   4.02
08:10:01 AM      4    102   0.03   0.08   2.12
08:20:01 AM      5    111   0.05   0.07   1.13
08:30:01 AM      6    110   0.06   0.06   0.60
...
```
<p>In the above example we see that the load was high from 6:30 AM to 7:50 AM, so that is where we need to focus our investigation. Sys-snap can print high resource using processes for a time range.
</p>
<h3>
<u>Polling sys-snap for specific information using --print</u>
</h3>
<p>
First, go on your server to the directory where the <a href="http://sys-snap.pl">sys-snap.pl</a> script is located, which is /root by default. The --print flag attempts to programmatically calculate what it calls memory and cpu scores. It does this by adding together the %MEM and %CPU columns, respectively. While mathematically incorrect, it gives us a general overview. You will see that each set of processes is sorted by user, and you’ll see a memory- and cpu- score displayed, similar to what is displayed below:
</p>

```
[~] ./sys-snap.pl --print 9:00 10:00
user: root           
cpu-score: 1.30         
memory-score: 299.60      
user: named          
cpu-score: 0.00         
memory-score: 28.60       
user: mysql          
cpu-score: 0.00         
memory-score: 80.60       
user: mailnull       
cpu-score: 0.00         
memory-score: 3.90        
user: dovecot        
cpu-score: 0.00         
memory-score: 1.30        
user: nobody         
cpu-score: 0.00         
memory-score: 19.50       
user: dovenull       
cpu-score: 0.00         
memory-score: 11.70       
[~]
```
<p>
The --print flag assumes you will be polling the sys-snap data for a specific time, so always pass the --print flag with a defined start and end time. For example, if we are trying to look at information between 6:30 and 7:50, as would be helpful given the output from our example above, this command would print information for the time range:
</p>

```
[~] /root/sys-snap.pl --print 6:30 7:50
```
<p>
When you start the script, old data is compressed into a tar file to prevent overwriting. To use sys-snap to parse old data, untar the file and pass the path using the --path flag:
</p>

```
[~] /root/sys-snap.pl --print 6:30 7:50 --dir=/system-snapshot.20150422
```
<p>
If we add the verbose flag to --print we can get even more detail:
</p>

```
[~] /root/sys-snap.pl --print 9:00 10:00 v
< manually truncated for brevity >
user: dovenull       
cpu-score: 0.00      
C: 0.00 proc: \_ dovecot/imap-login
C: 0.00 proc: \_ dovecot/pop3-login
memory-score: 14.40      
M: 8.00 proc: \_ dovecot/imap-login
M: 6.40 proc: \_ dovecot/pop3-login
< manually truncated for brevity >
```
<p>
sys-snap has a myriad of flags to make parsing through the information that is provides easier. Run the script with no flags to get the full list:
</p>

```
[~] ./sys-snap.pl
USAGE: ./sys-snap.pl [options]
--start : creates, disowns, and drops 'sys-snap.pl --start' process into the background
--print <start-time end-time>: Where time HH:MM, prints basic usage by default
--v | v : verbose output from --print
--check : checks if sys-snap is running
--stop : stops sys-snap after confirming PID info
--loadavg <start-time end-time>: Where time HH:MM, prints load average for time period - default 10 min interval
--max-lines : max number of processes printed per mem/cpu section
--no-cpu | --nc : skips CPU output
--no-mem | --nm : skips memory output
```
<p>
You can see some examples of these flags in use below in the ‘Advanced Examples’ section below.
</p>

<p>
In the example output below, the user 'eve' is showing the highest CPU usage for the interval, and you can see the command that was being run by that user:
</p>

```
user: dovecot         
memory-score: 84.30    memory-score:
M: 84.30 proc: \_ dovecot/auth
M: 0.00 proc: \_ dovecot/anvil
cpu-score: 6.90      
C: 6.90 proc: \_ dovecot/auth
C: 0.00 proc: \_ dovecot/anvil

user: eve
memory-score: 345.00
M: 345.00 proc: /usr/bin/php /home/eve/public_html/website.com/script.php
M: 0.00 proc: /usr/bin/ruby /usr/bin/mongrel_rails start -p 12008 -d -e production -P log/mongrel.pid
cpu-score: 23847.00
C: 23847.00 proc: /usr/bin/php /home/eve/public_html/website.com/script.php
C: 0.00 proc: /usr/bin/ruby /usr/bin/mongrel_rails start -p 12008 -d -e production -P log/mongrel.pid
```
<p>
Based on that output, the next step would be to investigate the '/home/eve/public_html/website.com/script.php script. This could be done by reading the script and checking the '/home/eve/access-logs/' logs to see what the script is doing. Many times there will be several processes and users that will need to be investigated. If a user is causing sever load, it might help to suspend them while the system administrator investigates the issue. If you have CloudLinux, the LVE manager could limit their resources and help increase server stability.
</p>
<p>
http://docs.cloudlinux.com/cpanel_lve_manager.html
</p>
<p>
If most of the users have the same resource usage but the server has high load, it’s time to think about upgrading the server hardware or moving some users to a different server.
</p>
<h1>
Advanced uses and examples
</h1>
<h3>
<u>Add an alias for quick access</u>
</h3>
<p>
If you want to easily run sys-snap from any directory, add this alias to your /etc/bashrc file:
</p>

```
alias syssnap="/root/sys-snap.pl"
```
<h3>
<u>Print only CPU scores</u>
</h3>
<p>If you think you have a user that is spiking the processor between 11am and 11:15am, you would run a command like this to narrow down the user:
</p>

```
[~] ./sys-snap.pl --print 11:00 11:15 --no-mem | head
user: brock             
cpu-score: 142.76  
user: root           
cpu-score: 46.20       
user: ntp            
cpu-score: 0.00        
user: snapper            
cpu-score: 0.00        
user: mailnull       
cpu-score: 0.00        
user: brock             
cpu-score: 0.00     
```
<h3>
<u>Limit the number of lines per user in verbose output</u>
</h3>
<p>
If you want to limit the number of lines that are output per user when you are parsing through the verbose output of --print, use the --max-lines flag.
</p>

```
[~] ./sys-snap.pl --print 10:00 11:00 v --max-lines 5 | head 13
user: root           
cpu-score: 47.70     
C: 41.00 proc: \_ spamd child
C: 6.00 proc: \_ cpanellogd - updating bandwidth
C: 0.70 proc: \_ [cpaneld - servi] <defunct>
C: 0.00 proc: \_ [cgroup]
C: 0.00 proc: \_ [flush-252:0]

memory-score: 541.60     
M: 386.70 proc: /usr/local/cpanel/3rdparty/bin/clamd
M: 65.60 proc: \_ spamd child
M: 23.40 proc: lfd - sleeping
M: 15.60 proc: tailwatchd
```
<h3>
<u>Display load averages (helpful for servers without Sar)</u>
</h3>
<p>If you want to print load averages for a given time frame, you can with the --loadavg flag.</p>

```
[~] ./sys-snap.pl --loadavg 11:00 11:30
Time	1min-avg 5min-avg 15min-avg
11:00	  0.19	   0.07		0.03
11:10	  0.06	   0.04		0.00
11:20	  0.00	   0.02		0.00
11:30	  0.06	   0.03		0.00
```
<p>
Add -i to change the interval between the load averages displayed
</p>

```
[~] ./sys-snap.pl --loadavg 11:00 11:30 --i=5

Time 	1min-avg 5min-avg 15min-avg
11:00	 0.19	  0.07		0.03
11:05	 0.03	  0.05		0.02
11:10	 0.06	  0.04		0.00
11:15 	 0.02	  0.05		0.00
11:20	 0.00	  0.02		0.00
11:25	 0.31	  0.14		0.10
11:30	 0.06	  0.03		0.00
```
<h3>
<u>Parsing archived data</u>
</h3>
<p>
When you start the script you will see that it archives historical data:
</p>

```
[~] cd /root/ && chmod 744 sys-snap.pl && perl sys-snap.pl --start
Sys-snap is not currently running
Start sys-snap logging to '/root/system-snapshot/' (y/n)?:y
Starting...
tar: Removing leading `/' from member names
[~]
```
<p>
If you want to access that historical data, you just need to unarchive the folder and pass the --dir flag:
</p>

```
[~] tar -xf system-snapshot.20150422.1341.tar.gz 
[~] ./sys-snap.pl --print 6:30 7:50 --dir=/root/system-snapshot.20150422.1341 | head -n11
user: root           
cpu-score: 64.20       
memory-score: 1696.60     
user: roompod        
cpu-score: 9.30        
memory-score: 2.10        
user: patrick        
cpu-score: 8.50        
memory-score: 13.10       
user: msusci    
cpu-score: 0.20        
[~] 
```
<h1>
Common problems
</h1>
<p>
You may see this error when attempting to install the script:
</p>

```
[~] ./sys-snap.pl --install

Can't locate Time/Piece.pm in @INC (@INC contains: /usr/local/lib/perl5/5.8.8/x86_64-linux /usr/local/lib/perl5/5.8.8 /usr/local/lib/perl5/site_perl/5.8.8/x86_64-linux /usr/local/lib/perl5/site_perl/5.8.8 /usr/local/lib/perl5/site_perl .) at ./sys-snap.pl line 126.
BEGIN failed--compilation aborted at ./sys-snap.pl line 126.
[~]
```
<p>
<span style="color: rgb(0,0,0);">You can correct it with this command:</span>
</p>

```
[~] cpan -i Time::Piece
```
