#!/usr/bin/perl
# Copyright (C) 2015
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

# Author Bryan Christensen

use warnings;
use strict;
use Getopt::Long;

my %opt = (
    'start'         => 0,
    'stop'          => 0,
    'check'         => 0,
    'print'         => 0,
    'loadavg'       => 0,
    'help'          => 0,
    'network'       => 0,
    'io'            => 0,
    'print_cpu'     => 1,
    'print_memory'  => 1,
    'interval'      => 10,
    'loadavg'       => 0,
    'dir'           => '/root/system-snapshot',
    'verbose'       => '0',
    'max-lines'     => '20',
    'line_length'   => '145',
);

GetOptions( \%opt,
    'help|h+',
    'print',
    'network',
    'start',
    'stop',
    'check|c',
    'loadavg',
    'io',
    'cpu!'              => \$opt{'print_cpu'},
    'mem!'              => \$opt{'print_memory'},
    'interval|i=i'      => \$opt{'interval'},
    'dir|d=s'           => \$opt{'dir'},
    'verbose|v!'        => \$opt{'verbose'},
    'max-lines|ml=i'    => \$opt{'max-lines'},
) or usage();

########################################################
# start of parameters that don't need time
########################################################

if ($opt{'help'}) {
    usage();
    exit;
}
elsif ($opt{'start'}) {
    run_install();
    exit;
}
elsif ($opt{'stop'}) {
    stop_syssnap();
    exit;
}
elsif ($opt{'check'}) {
    check_status();
    exit;
}

########################################################
# start of parameters that need time
########################################################

# two extra parameters are expected if you are using options that need time
if (@ARGV < 2) {
    usage();
    #print "No time range specified\n";
    exit();
}
elsif(@ARGV > 3) {
    print "Too many unknown parameters\n";
    exit;
}
elsif (@ARGV == 2){
    $opt{'time1'} = $ARGV[0];
    $opt{'time2'} = $ARGV[1];
}

if ($opt{'loadavg'}) {
    loadavg(\%opt);
    exit;
}

if ($opt{'io'}) {
    snap_io(\%opt);
    exit;
}

if ($opt{'print'}) {
    snap_print_range(\%opt);
    exit;
}

if($opt{'network'}) {
    snap_network(\%opt);
    exit;
}

# I don't think the logic flow should ever hit this, but just in case
usage();
exit;

sub snap_network {
    my %opt = %{shift @_};
    my $time1 = $opt{'time1'};
    my $time2 = $opt{'time2'};
    my $snapshot_dir = $opt{'dir'};
    my $detail_level= $opt{'verbose'};
    my $max_lines= $opt{'max-lines'};
    my $print_cpu = $opt{'print_cpu'};
    my $print_memory = $opt{'print_memory'};
    # old school 80 is standard, but 145 works well with 1366 width monitor
    my $line_length = $opt{'line_length'};

    #root_dir is legacy param, will remove later
    my $root_dir = "";

    # the default formatting where the process ID is added needs 16 lines
    # subtracting 16 here will make the specified width more "true"
    $line_length = $line_length - 16;

    module_sanity_check();
    eval("use Time::Piece;");
    if ($@) {
        print "***\nCould not install Time::Piece - try manually installing.\n***\n";
        exit;
    }

    my ($time1_hour, $time1_minute, $time2_hour, $time2_minute) = &parse_check_time($time1, $time2);
    my @snap_log_files = &get_range($root_dir, $snapshot_dir, $time1_hour, $time1_minute, $time2_hour, $time2_minute);

    my %ip_connections;
    my (%localip, %foreignip);
    #print "Time\t1min-avg\t5min-avg\t15min-avg\n";
    foreach my $file_name (@snap_log_files) {

        open (my $FILE, "<", $file_name) or next; #die "Couldn't open file: $!";
        my $string = join("", <$FILE>);
        close ($FILE);

        my @lines;
        # reading line by line to split the sections might be faster
        my $matchme = "^Active Internet connections [^\n]+\n";
        #my $matchme = "^Process List:\n\nUSER[^\n]+COMMAND\n";
        if($string =~ /$matchme(.*)\nActive UNIX domain sockets \(servers and established\)/sm){
            my $baseString=$1;
            @lines = split(/\n/, $baseString);
        }

        # could add ports in the future and connection state
        # should skip listen and time_wait entries
        foreach my $line (@lines) {
            if ($line =~ /[a-z]{3}\s+\d+\s+\d+\s+(\d+\.\d+\.\d+\.\d+):\d+\s+(\d+\.\d+\.\d+\.\d+):\d+\s+(?!TIME_WAIT)/) {
                if ($ip_connections{$1}{$2}){
                    $ip_connections{$1}{$2} += 1;
                }
                else {
                    $ip_connections{$1}{$2} = 1;
                }
            }
        }
    }

    foreach my $localip (keys %ip_connections){
        my @sorted_ip = sort { $ip_connections{$localip}{$b} <=>
            $ip_connections{$localip}{$a} } keys %{$ip_connections{$localip}};
        print "$localip: \n";
        for (@sorted_ip) {
            printf "\t%-15s %-8d\n", $_, $ip_connections{$localip}{$_};
        }
        print "\n";
    }
}

sub usage {
    my $text = <<"ENDTXT";
USAGE:
./sys-snap.pl [options]
    --start : Creates, disowns, and drops 'sys-snap.pl --start' process into the background
    --stop : stops sys-snap after confirming PID info
    --check : Checks if sys-snap is running
    --print <start-time end-time> : Where time HH:MM, prints basic usage by default
    --network <start-time end-time> : Prints IP connections durring time range
    --v | v : verbose output from --print
    --max-lines : max number of processes printed per mem/cpu section, default is 20
    --ll : line length, default is 145
    --no-cpu | --nc : skips CPU output
    --no-mem | --nm : skips memory output
    --loadavg <start-time end-time>: Where time HH:MM, prints load average for time period - default 10 min interval
    --dir : specifies a different sys-snap folder for --print and --loadavg

ENDTXT

    print $text;
    exit;
}

sub snap_io {
    eval("use Time::Piece;");
    my %opt = %{shift @_};
    my $time1 = $opt{'time1'};
    my $time2 = $opt{'time2'};
    my $interval = $opt{'interval'};
    my $snapshot_dir = $opt{'dir'};

    #root_dir is legacy param, will remove later
    my $root_dir = "";

    if($interval > 60 || $interval < 0) {
        $interval = 10;
    }

    my ($time1_hour, $time1_minute, $time2_hour, $time2_minute) = &parse_check_time($time1, $time2);
    my @snap_log_files = &get_range($root_dir, $snapshot_dir, $time1_hour, $time1_minute, $time2_hour, $time2_minute);

    print "avg-cpu:\t%user\t%nice\t%system\t%iowait\t%steal\t%idle\n";
    foreach my $file_name (@snap_log_files) {
        # load information is currently printed to the first line
        # only need to read first line
        open (my $FILE, "<", $file_name) or next; #die "Couldn't open file: $!";
        #my $string = <$FILE>;
        my $string = join("", <$FILE>);
        my ($min) = $string =~ m{^\d+\s+\d+\s+(\d+)\s+Load Average:}g;
        #print "$min\n";
        close ($FILE);

        my @lines;
        if($string =~ /^IO wait:\n(.*)\nMYSQL Processes:$/sm){
            my $baseString=$1;
            @lines = split(/\n/, $baseString);
        }

        foreach my $line (@lines) {
            my ($io_user, $nice, $io_system, $io_wait, $steal, $idle);
            ($io_user, $nice, $io_system, $io_wait, $steal, $idle) = $line =~ m{^\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)};
            if(defined $io_user && ($min % $interval == 0)){
                print "\t\t$io_user\t$nice\t$io_system\t$io_wait\t$steal\t$idle\n";
            }
        }
    }
    return;
}

sub loadavg {
    eval("use Time::Piece;");
    my %opt = %{shift @_};
    my $time1 = $opt{'time1'};
    my $time2 = $opt{'time2'};
    my $interval = $opt{'interval'};
    my $snapshot_dir = $opt{'dir'};

    #root_dir is legacy param, will remove later
    my $root_dir = "";

    if($interval > 60 || $interval < 0) {
        $interval = 10;
    }

    my ($time1_hour, $time1_minute, $time2_hour, $time2_minute) = &parse_check_time($time1, $time2);

    my @snap_log_files = &get_range($root_dir, $snapshot_dir, $time1_hour, $time1_minute, $time2_hour, $time2_minute);

    print "Time\t1min-avg\t5min-avg\t15min-avg\n";

    foreach my $file_name (@snap_log_files) {
        # load information is currently printed to the first line
        # only need to read first line
        open (my $FILE, "<", $file_name) or next; #die "Couldn't open file: $!";
        my $string = <$FILE>;
        close ($FILE);

        my ($avg1min, $avg5min, $avg15min, $hour, $min);
        ($hour, $min, $avg1min, $avg5min, $avg15min) = $string =~ m{^\d+\s+(\d+)\s+(\d+)\s+Load Average: (\d+\.\d+)\s(\d+\.\d+)\s(\d+\.\d+)\s.*$};

        if (defined $hour && defined $min & defined $avg1min && defined $avg5min && defined $avg15min && ($min % $interval == 0) ){
            $min = "0" . $min if ($min =~ m{^\d$});
            print "$hour:$min\t$avg1min\t\t$avg5min\t\t$avg15min\n";
        }
    }
    return;
}

sub stop_syssnap {
    my $pid;
    # prevent check_status from printing to terminal
    {
        local *STDOUT;
        open (STDOUT, '>', '/dev/null') or die "Can't access /dev/null";
        $pid = &check_status();
    }
    if ($pid =~ /[\d+]/) {
        #print "Test: $pid\n";
        delete @ENV{'PATH', 'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
        my $running_pid = "false";
        my $ps_info = `ps -e -o pid,user,args | grep "[s]ys-snap.pl --start"`;
        if ($ps_info =~ /^\s*([0-9]+)\s+root\s+(\/usr\/bin\/perl\s+\.\/|perl\s+)sys-snap\.pl\s+--start/ ) {
            $running_pid = $1;
        }
        print "Current process: $ps_info";
        print "Stop this process (y/n)?:";

        my $choice = "0";
        $choice = <STDIN>;
        while ($choice !~ /[yn]/i ) {
            print "Stop this process (y/n)?:";
            $choice = <STDIN>;
            chomp ($choice);
        }
        if($choice =~ /[y]/i) {
            print "Stopping $pid\n";
            `kill -3 $pid`;
            exit;
        }
        else { print "Exiting...\n"; exit; }
    }
    else {
        print "Sys-snap is not currently running\n";
    }
    return;
}

# needs to be cleaned up
sub check_status {

    delete @ENV{'PATH', 'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};
    my $ps_info = `ps -e -o pid,user,args | grep "[s]ys-snap.pl [-]\\{1,2\\}start"`;

    my @pids = split("\n",$ps_info);
    my $current_script = $$;
    my $running_pid;

    if(@pids > 2) {
        print "Multiple sys-snap instances running?\n";
    }

    # if sys-snap is running there will be 2 matches, the current running pid, and the pid of newly invoked process
    # this block tries to confirm that there is another intance running that does not match the pid of the newly invoked
    elsif (@pids eq 2) {
        if( $pids[0] =~ /^\s*([0-9]+)\s+root\s+(\/usr\/bin\/perl\s+\.\/|perl\s+)sys-snap\.pl\s+[-]{1,2}start/ ) {
            my $tmp_pid = $1;
            if($tmp_pid != $current_script) {
                $running_pid=$tmp_pid;
            }
        }

        if( $pids[1] =~ /^\s*([0-9]+)\s+root\s+(\/usr\/bin\/perl\s+\.\/|perl\s+)sys-snap\.pl\s+[-]{1,2}start/ ) {
            my $tmp_pid = $1;
            if($tmp_pid != $current_script) {
                $running_pid=$tmp_pid;
            }
        }
        if( !defined($running_pid) ) { print "Could not find PID, process might be running.\n"; return "on"; }

        print "Sys-snap is running, PID: $running_pid\n";
        return $running_pid;
    }
    elsif (defined $pids[0]) {

        if( $pids[0] =~ /^\s*([0-9]+)\s+root\s+(\/usr\/bin\/perl\s+\.\/|perl\s+)sys-snap\.pl\s+[-]{1,2}start/ ) {

            my $tmp_pid = $1;
            if ($tmp_pid != $current_script) {
                print "Sys-snap is running, PID: $tmp_pid\n"; return $tmp_pid;
            } elsif( $tmp_pid eq $current_script ) { print "Sys-snap is not currently running\n"; return "off"; }
        }
    }
    else { print "Sys-snap not currently running.\n"; return "off"; }

    print "Failed PID checks\n";
    return "off";
}

sub parse_check_time {

    my $time1 = shift;
    my $time2 = shift;

    if (!defined $time1 || !defined $time2) { print "Need 2 parameters, \"./snap-print start-time end-time\"\n"; exit;}

    my ($time1_hour, $time1_minute, $time2_hour, $time2_minute);

    if ( ($time1_hour, $time1_minute) = $time1 =~ m{^(\d{1,2}):(\d{2})$}){
        if($time1_hour >= 0 && $time1_hour <= 23 && $time1_minute >= 0 && $time1_minute <= 59) {
            #print "$time1_hour $time1_minute\n";
        } else { print "Fail: Fictitious time.\n"; exit; }

    } else { print "Fail: Could not parse start time\n"; exit; }

    if ( ($time2_hour, $time2_minute) = $time2 =~ m{(\d{1,2}):(\d{2})}){
        if($time2_hour >= 0 && $time2_hour <= 23 && $time2_minute >= 0 && $time2_minute <= 59) {
            #print $time2_hour $time2_minute\n";
        } else { print "Fail: Fictitious time.\n"; exit; }

    } else { print "Fail: Could not parse end time\n"; exit; }

    if (defined $time1_hour && defined $time2_hour ) { return ($time1_hour, $time1_minute, $time2_hour, $time2_minute); }
    return 0;
}

sub snap_print_range {
    my %opt = %{shift @_};
    my $time1 = $opt{'time1'};
    my $time2 = $opt{'time2'};
    my $snapshot_dir = $opt{'dir'};
    my $detail_level= $opt{'verbose'};
    my $max_lines= $opt{'max-lines'};
    my $print_cpu = $opt{'print_cpu'};
    my $print_memory = $opt{'print_memory'};
    # old school 80 is standard, but 145 works well with 1366 width monitor
    my $line_length = $opt{'line_length'};

    #root_dir is legacy param, will remove later
    my $root_dir = "";

    # the default formatting where the process ID is added needs 16 lines
    # subtracting 16 here will make the specified width more "true"
    $line_length = $line_length - 16;

    if (!defined $time1 || !defined $time2) { print "Need 2 parameters, \"./snap-print start-time end-time\"\n"; exit;}

    module_sanity_check();
    eval("use Time::Piece;");
    if ($@) {
        print "***\nCould not install Time::Piece - try manually installing.\n***\n";
        exit;
    }

    use Time::Seconds;

    # not using this yet, but if we parse a range of data that crosses this file the resulting data is noncontigous
    # and might be misleading. printing a warning might be apropriate in this scenario or having some other flag
    # to indicate this has happened
    #my $newest_file = qx(ls -la ${root_dir}/system-snapshot/current);

    my ($time1_hour, $time1_minute, $time2_hour, $time2_minute) = &parse_check_time($time1, $time2);

    # get the files we want to read
    my @snap_log_files = &get_range($root_dir, $snapshot_dir, $time1_hour, $time1_minute, $time2_hour, $time2_minute);

    my ($tmp1, $tmp2) = &read_logs(\@snap_log_files);

    # users cumulative CPU and Mem score
    my %basic_usage = %$tmp1;

    #raw data from logs
    my %process_list_data = %$tmp2;

    # weighted process & memory
    my %users_wcpu_process;
    my %users_wmemory_process;

    if ($detail_level == 0) { &run_basic(\%basic_usage, $print_cpu, $print_memory); exit}

    # adding up memory and CPU usage per user's process
    foreach my $user (sort keys %process_list_data) {
        foreach my $process (sort keys %{ $process_list_data{$user} }) {

            $users_wcpu_process{$user}{$process} += $process_list_data{$user}{$process}{'cpu'};
            $users_wmemory_process{$user}{$process} += $process_list_data{$user}{$process}{'memory'};
        }
    }

    my $sort_param;
    if ($print_cpu) { $sort_param = "cpu"; }
    else { $sort_param = "memory"; }

    foreach my $user ( sort { $basic_usage{$b}->{$sort_param} <=> $basic_usage{$a}->{$sort_param} } keys %basic_usage ) {

        printf "user: %-15s", $user;

        my $num_lines=0;
        if($print_cpu){

            my @sorted_cpu = sort { $users_wcpu_process{$user}{$b} <=>
                $users_wcpu_process{$user}{$a} } keys %{$users_wcpu_process{$user}};

            printf "\n\tcpu-score: %-10.2f\n", $basic_usage{$user}{'cpu'};
            for (@sorted_cpu) {
                printf "\t\tC: %4.2f proc: ", $users_wcpu_process{$user}{$_};
                print substr($_, 0, $line_length) . "\n";
                if ($num_lines >= $max_lines-1) { last; }
                else { $num_lines += 1; }
            }
        }

        $num_lines=0;
        if($print_memory) {

            my @sorted_mem = sort { $users_wmemory_process{$user}{$b} <=>
                $users_wmemory_process{$user}{$a} } keys %{$users_wmemory_process{$user}};

            printf "\n\tmemory-score: %-11.2f\n", $basic_usage{$user}{'memory'};
            for (@sorted_mem) {
                printf "\t\tM: %4.2f proc: ", $users_wmemory_process{$user}{$_};
                print substr($_, 0, $line_length) . "\n";
                if ($num_lines >= $max_lines-1) { last; }
                else { $num_lines += 1; }
            }
        }
        print "\n";
    }
    exit;
}

## should be rewritten to take parameters of log subsections to be read
# returns hash of hashes
sub read_logs {

    my $tmp = shift;
    my @snap_log_files = @$tmp;

    my %process_list_data;
    my %basic_usage;

    foreach my $file_name (@snap_log_files) {

        my @lines;

        open (my $FILE, "<", $file_name) or next; #die "Couldn't open file: $!";
        my $string = join("", <$FILE>);
        close ($FILE);

        # reading line by line to split the sections might be faster
        my $matchme = "^Process List:\n\nUSER[^\n]+COMMAND\n";
        if($string =~ /^$matchme(.*)\nNetwork Connections\:$/sm){
            my $baseString=$1;
            @lines = split(/\n/, $baseString);
        }

        foreach my $l (@lines) {
            my ($user, $cpu, $memory, $command);
            ($user, $cpu, $memory, $command) = $l =~  m{^(\w+)\s+\d+\s+(\d{1,2}\.\d)\s+(\d{1,2}\.\d).*\d{1,2}:\d{2}\s+(.*)$};

            if (defined $user && defined $cpu && defined $memory && defined $command) {

                if ($user !~ m/[a-zA-Z0-9_\.\-]+/) { next; }
                if ($cpu !~ m/[0-9\.]+/ && $memory !~ m/[0-9\.]+/) { next; }
                $basic_usage{$user}{'memory'} += $memory;
                $basic_usage{$user}{'cpu'} += $cpu;
                # agrigate hash? of commands - roll object

                # if the process is the same, accumulate it, if not create it
                # assuming if we have a memory value for a command, we should have a cpu value - nothing can ever go wrong here :smiley face:
                if (defined $process_list_data{$user}{$command}{'memory'}) {
                    $process_list_data{$user}{$command}{'memory'} += $memory;
                    $process_list_data{$user}{$command}{'cpu'} += $cpu;
                }
                else {
                    $process_list_data{$user}{$command}{'cpu'} = $cpu;
                    $process_list_data{$user}{$command}{'memory'} = $memory;
                }
            }
        }
    }
    return (\%basic_usage, \%process_list_data);
}

# returns ordered array of stings that represent file location
# could create $accuracy variable to run modulo integers for faster processing at expense of accuracy
sub get_range {

    my $root_dir = shift;
    my $snapshot_dir = shift;
    my $time1_hour = shift;
    my $time1_minute = shift;
    my $time2_hour = shift;
    my $time2_minute = shift;
    my $time1 = "$time1_hour:$time1_minute";
    my $time2 = "$time2_hour:$time2_minute";

    my @snap_log_files;
    my ($file_hour, $file_minute);
    # Even if we want to ignore the date, Time::Piece will create one. This is probably easier than rolling a custom time cycle for over night periods such as 23:57 0:45,
    # and should make modification easier if longer date ranges are added too.
    # Mind the date format 'DAY MONTH YEAR(XXXX)'
    my $start_time = Time::Piece->strptime("2-2-1993 $time1", "%d-%m-%Y %H:%M");
    my $end_time;

    if($time1_hour < $time2_hour || ($time1_hour == $time2_hour && $time1_minute < $time2_minute)) {
        $end_time = Time::Piece->strptime("2-2-1993 $time2", "%d-%m-%Y %H:%M");
    } else {
        $end_time = Time::Piece->strptime("3-2-1993 $time2", "%d-%m-%Y %H:%M");
    }

    while ($start_time <= $end_time ) {

        #print $start_time->strftime('%H:%M') . "\n";
        ($file_hour,$file_minute) = split( /:/, $start_time->strftime('%H:%M') );

        #sys-snap not currently appending 0's to the front of files
        $file_minute =~ s/^0(\d)$/$1/;
        $file_hour =~ s/^0(\d)$/$1/;
        #print "$root_dir$snapshot_dir/$file_hour/$file_minute.log\n";
        push @snap_log_files, "$root_dir$snapshot_dir/$file_hour/$file_minute.log";
        $start_time += 60;
    }

    return @snap_log_files;
}

# since mem and cpu info gets printed to the same line, we already have the data at this point,
# and even sorting a large number of users by usage is relativly inexpensive, just going to mute unwanted output
sub run_basic {
    my $tmp = shift;
    my $print_cpu = shift;
    my $print_memory = shift;
    my %basic_usage;
    %basic_usage = %$tmp;

    my $sortby = 'cpu';
    if ($print_cpu != 1) { $sortby = 'memory'; }
    foreach my $key (
        sort { $basic_usage{$b}->{$sortby} <=> $basic_usage{$a}->{$sortby} }
        keys %basic_usage
    )
    {
        my $value = $basic_usage{$key};
        #printf( "user: %-15s\n\tcpu-score: %-12.2f \n\tmemory-score: %-12.2f\n\n", $key, $value->{cpu}, $value->{memory} );
        printf( "user: %-15s\n", $key);
        printf("\tcpu-score: %-12.2f\n", $value->{cpu}) if $print_cpu;
        printf("\tmemory-score: %-12.2f\n", $value->{memory}) if $print_memory;
    }
    print "\n";

    exit;
}

sub run_install {

    my $tmp_check = &check_status;
    if( $tmp_check =~ /[\d]+/ ) {
        exit;
    }
    else
    {
        print "Start sys-snap logging to '/root/system-snapshot/' (y/n)?:";
        my $choice = "0";
        $choice = <STDIN>;
        while ($choice !~ /[yn]/i ) {
            print "Start sys-snap logging to '/root/system-snapshot/' (y/n)?:";
            $choice = <STDIN>;
            chomp ($choice);
        }
        if($choice =~ /[y]/i) {
            print "Starting...\n";
        }
        else { print "Exiting...\n"; exit; }
    }

    use File::Path qw(rmtree);
    use POSIX qw(setsid);

    ###############
    # Set Options #
    ###############

    # Set the time between snapshots in seconds
    my $sleep_time = 60;

    # The base directory under which to build the directory where snapshots are stored.
    my $root_dir = '/root';

    # Sometimes you won't have mysql and/or you won't have the root password to put in a .my.cnf file
    # if that's the case, set this to 0
    my $mysql = 1;

    # If the server has lighttpd or some other webserver, set this to 0
    # cPanel is autodetected later, so this setting is not used if running cPanel.
    my $apache = 1;

    # If you want extended data, set this to 1
    my $max_data = 0;

    # Get the date, hour, and min for various tasks
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    $year += 1900;    # Format year correctly
    $mon++;           # Format month correctly
    $mon  = 0 . $mon  if $mon < 10;
    $mday = 0 . $mday if $mday < 10;
    my $date = $year . $mon . $mday;

    # Ensure target directory exists and is writable
    if ( !-d $root_dir ) {
        die "$root_dir is not a directory\n";
    }
    elsif ( !-w $root_dir ) {
        die "$root_dir is not writable\n";
    }

    if ( -d "$root_dir/system-snapshot" ) {
        system 'tar', 'czf', "${root_dir}/system-snapshot.${date}.${hour}${min}.tar.gz", "${root_dir}/system-snapshot";
        rmtree( "$root_dir/system-snapshot" );
    }

    if ( !-d "$root_dir/system-snapshot" ) {
        mkdir "$root_dir/system-snapshot";
    }

    # try to split process into background
    chdir '/' or die "Can't chdir to /: $!";
    open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
    open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
    defined(my $pid = fork) or die "Can't fork: $!";
    exit if $pid;
    setsid or die "Can't start a new session: $!";
    open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";

    ##########
    # Main() #
    ##########

    while (1) {

        # Ensure we have a current date/time
        ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
        $year += 1900;    # Format year correctly
        $mon++;           # Format month correctly
        $mon  = 0 . $mon  if $mon < 10;
        $mday = 0 . $mday if $mday < 10;
        $date = $year . $mon . $mday;

        # go to the next log file
        mkdir "$root_dir/system-snapshot/$hour";
        my $current_interval = "$hour/$min";

        my $logfile = "$root_dir/system-snapshot/$current_interval.log";
        open( my $LOG, '>', $logfile )
            or die "Could not open log file $logfile, $!\n";

        # start actually logging #
        my $load = qx(cat /proc/loadavg);
        #print $LOG "Load Average:\n\n";  # without this line, you can get historical loads with head -n1 *
        print $LOG "$date $hour $min Load Average: $load\n";

        print $LOG "Memory Usage:\n\n";
        print $LOG qx(cat /proc/meminfo), "\n";

        print $LOG "Virtual Memory Stats:\n\n";
        print $LOG qx(vmstat 1 10), "\n";

        print $LOG "Process List:\n\n";
        print $LOG qx(ps auwwxf), "\n";

        print $LOG "Network Connections:\n\n";
        print $LOG qx(netstat -anp), "\n";

        print $LOG "IO wait:\n\n";
        print $LOG qx(iostat), "\n";

        # optional logging
        if ($mysql) {
            print $LOG "MYSQL Processes:\n\n";
            print $LOG qx(mysqladmin proc), "\n";
        }

        print $LOG "Apache Processes:\n\n";
        if ( -f '/usr/local/cpanel/cpanel' ) {
            print $LOG qx(lynx --dump localhost/whm-server-status), "\n";
        }
        elsif ($apache) {
            print $LOG qx#lynx -width=1024 -dump http://localhost/server-status | egrep '(Client.+Request|GET|POST|HEAD)'#, "\n";
        }

        if ($max_data) {
            print $LOG "Process List for user Nobody:\n\n";
            my @process_list = qx(ps aux | grep [n]obody | awk '{print \$2}');
            foreach my $process (@process_list) {
                print $LOG qx(ls -al /proc/$process | grep cwd | grep home);
            }
            print $LOG "List of Open Files:\n\n";
            print $LOG qx(lsof), "\n";
        }

        close $LOG;

        # rotate the "current" pointer
        rmtree( "$root_dir/system-snapshot/current" );
        symlink "${current_interval}.log", "$root_dir/system-snapshot/current";

        sleep($sleep_time);
    }
}

sub module_sanity_check {
    eval("use Time::Piece;");
    if ($@) {
        print "WARNING: Perl Module Time::Piece.pm not installed!\n";
        print "Would you like sys-snap to attempt to install this moduel(y/n):";

        my $choice = <STDIN>;
        if ($choice =~ /yes|y/i) {
            print "Installing now - Please stand by.\n";
            system("cpan -i Time::Piece");
        }
        else {
            exit;
        }
    }
    return;
}
