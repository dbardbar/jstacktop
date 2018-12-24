use strict;

use File::Slurp;
use Data::Dumper;
use Time::HiRes qw(time usleep);

my $JSTACK_COMMAND_NID_PATTERN = qr/nid=0x(.*?) /;
my $SLEEP_TIME = 1.5;

main();

sub main {
	my $pid = $ARGV[0];
	if (!$pid) {
		print "Usage: fstool jstacktop [pid] -s\n";
		print "\t-s - suppress stacks with 0% CPU\n";
		exit(1);
	}
	my $arg1 = $ARGV[1];
	my $suppress_zero_cpu = $arg1 eq "-s";
	append_top_CPU_to_jstack_output_and_print($pid, $suppress_zero_cpu);
}

sub append_top_CPU_to_jstack_output_and_print {
	my ($pid, $suppress_zero_cpu) = @_;
	my $thread_and_cpu_list = get_pid_and_cpu_list($pid);
	my $jstack_chunks_per_thread_id = get_jstack_per_thread($pid);
	for my $thread_and_cpu (@$thread_and_cpu_list) {
		my $threadId = $thread_and_cpu->[0];
		my $cpuUsage = $thread_and_cpu->[1];
		my $shouldPrint = ($suppress_zero_cpu == 0 || $cpuUsage > 0);
		if ($shouldPrint) {
			printJstackForThread($threadId, $cpuUsage, $jstack_chunks_per_thread_id);
		}
		delete $jstack_chunks_per_thread_id -> {$threadId};
	}
	foreach my $leftOver (values %$jstack_chunks_per_thread_id) {
		print $leftOver;
	}
}


sub printJstackForThread {
	my ($threadId, $cpuUsage, $stack_per_thread) = @_;
	my $cpuUsageStr = "%CPU ".$cpuUsage."\n";
	my $threadStack = $stack_per_thread -> {$threadId};
	return if not defined $threadStack;
	$threadStack =~ s/(.*?)\n(.*)/$1 $cpuUsageStr $2/;
	print $threadStack;
}

sub get_jstack_per_thread {
	my ($pid) = @_;
	my $jstackOutput = `jstack $pid`;
	my @splitedJstackOutput = split/\n\n/, $jstackOutput;
	my $jstackChunksPerThradId = {};

	for my $chunk (@splitedJstackOutput) {
		if ($chunk =~ $JSTACK_COMMAND_NID_PATTERN) {
			my $nativeThreadIdHex = $1;
			my $nativeThreadIdDec = hex $nativeThreadIdHex;
			$jstackChunksPerThradId -> {$nativeThreadIdDec} = $chunk."\n\n";
		} else {
			print "$chunk\n\n";
		}
	}
	return $jstackChunksPerThradId;
}

sub get_pid_and_cpu_list {
	my ($pid) = @_;
	my $ticks_per_second = `getconf CLK_TCK`;
	my $threads = get_threads_of_pid($pid);
	my $start_time = time();
	my $first_cpu_ticks = get_cpu_ticks_of_threads($pid, $threads);
	usleep $SLEEP_TIME * 1_000_000;
	my $second_cpu_ticks = get_cpu_ticks_of_threads($pid, $threads);
	my $end_time = time();
	my $actual_sampling_time = $end_time - $start_time;
	my $pid_and_cpu_list = [];
	for my $thread_id (@$threads) {
		#print $thread."\n\n\n";
		next if not exists $first_cpu_ticks->{$thread_id};
		next if not exists $second_cpu_ticks->{$thread_id};
		my $delta_ticks = $second_cpu_ticks->{$thread_id} - $first_cpu_ticks->{$thread_id};
		my $cpuUsage = int(100 * ($delta_ticks / $ticks_per_second) / $actual_sampling_time);
		my $pair = [$thread_id, $cpuUsage];
		push @$pid_and_cpu_list, $pair;
	}
	my @pid_and_cpu_list_sorted = sort { $b->[1] <=> $a->[1] } @$pid_and_cpu_list;
	return \@pid_and_cpu_list_sorted;
}

sub get_threads_of_pid {
	my ($pid) = @_;
	my $threads = [];

	my $task_dir = "/proc/$pid/task";
	if (!-d $task_dir) {
		print "process $pid does not exist\n";
		exit(1);
	}
	#print $task_dir;
	opendir(DIR, $task_dir) or die $!;
	while (my $file = readdir(DIR)) {
		next if $file eq "..";
		next if $file eq ".";
		#print "$file\n";
		push @$threads, $file;
	}
	closedir(DIR);
	return $threads;
}

sub get_cpu_ticks_of_threads {
	my ($pid, $threads) = @_;
	my $ticks_per_thread = {};
	for my $thread (@$threads) {
		my $stat_file_for_thread = "/proc/$pid/task/$thread/stat";
		my $data;
		eval {
			$data = read_file($stat_file_for_thread);
		};
		next if $@; # ignore errors. thread perhaps terminated.
		my @data_fields = split/ /, $data;
		#print "@data_fields";
		my $cpu_ticks = $data_fields[13] + $data_fields[14];
		#print "$thread $data_fields[13] $data_fields[14] $cpu_ticks\n\n";
		$ticks_per_thread -> {$thread} = $cpu_ticks;
	}
	return $ticks_per_thread;
}
