#!/usr/bin/perl

# Linux Chooser

use strict;
use warnings;
use utf8;
use Net::Atalk::NBP;  # For AppleTalk NBP lookup
use Term::ReadLine;
use URI::Escape;      # For URL encoding
use File::Path qw(make_path);  # For creating directories
use Log::Log4perl;


Log::Log4perl->init('/root/log4perl.conf');


# ENABLE DETAILED DIAGNOSTICS
use diagnostics;

# SET UTF-8 OUTPUT
binmode STDOUT, ":utf8";

# INITIALIZE LOG4PERL FOR DEBUGGING
my $log_conf = q(
    log4perl.rootLogger              = DEBUG, Screen
    log4perl.appender.Screen          = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr   = 0
    log4perl.appender.Screen.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %p %m %n
);
Log::Log4perl->init( \$log_conf );
my $logger = Log::Log4perl->get_logger("");

# TRACK DISCOVERED SERVERS
my @discovered_servers;
my %processed_hosts;

# CREATE A SINGLE Term::ReadLine INSTANCE
my $term = Term::ReadLine->new('AFP Chooser');

# DISCOVERY PART
# DISCOVER AFP SERVERS OVER APPLETALK
sub discover_afp_servers_atalk {
    my @results;
    eval {
        @results = Net::Atalk::NBP::NBPLookup(undef, 'AFPServer');
    };

    if ($@) {
        print "AppleTalk stack is probably out of order: $@\n";
        return;
    }

    foreach my $entry (@results) {
        my $hostname = $entry->[3];
        my $address  = $entry->[0];
        my $port     = $entry->[1];

        # Split AppleTalk address into network and node
        my ($network, $node) = split(/\./, $address);

        # Skip if already processed
        next if exists $processed_hosts{"$network.$node"};
        $processed_hosts{"$network.$node"} = 1;

        print "\nFound AppleTalk AFP Server: $hostname at $network.$node (Port: $port)\n";

        # Store server info for selection
        push @discovered_servers, {
            name    => $hostname,
            host    => $hostname,
            port    => $port,
            network => $network,
            node    => $node,
        };
    }
}

# SELECTION PART
# DISPLAY AVAILABLE SERVERS AND ALLOW USER TO CHOOSE
sub choose_server {
    print "\nAvailable AFP Servers:\n";
    for (my $i = 0; $i < @discovered_servers; $i++) {
        print "[$i] $discovered_servers[$i]->{name} ($discovered_servers[$i]->{network}.$discovered_servers[$i]->{node}:$discovered_servers[$i]->{port})\n";
    }
    my $choice = $term->readline("\nChoose a server (0-" . ($#discovered_servers) . "): ");
    return $discovered_servers[$choice] if defined $choice && $choice =~ /^\d+$/ && $choice <= $#discovered_servers;
    return undef;
}

# VOLUME LISTING PART
# SHOW AVAILABLE VOLUMES FOR THE SELECTED SERVER
sub show_volumes {
    my ($server, $username, $password) = @_;

    # CONSTRUCT AFP URL USING APPLETALK EXPLICITLY
    my $afp_url;
    if ($username && $password) {
        $afp_url = "afp:/at/$username:$password\@$server->{host}/";
    } else {
        $afp_url = "afp:/at/$server->{host}/";  # No User Authent (anonymous login)
    }

    # DEBUG: SHOW THE CONSTRUCTED AFP URL
    print "\n[DEBUG] Constructed AFP URL: $afp_url\n";

    # CALL afpclient.pl TO LIST VOLUMES
    print "\nFetching available volumes for $server->{name}...\n";
    my $command = "afpclient.pl \"$afp_url\"";

    # DEBUG: SHOW THE EXACT COMMAND BEING EXECUTED
    print "\n[DEBUG] Executing command: $command\n";

    my @volumes = `$command 2>&1`;  # Capture both stdout and stderr

    # DEBUG: DISPLAY THE RAW OUTPUT FROM afpclient.pl
    print "\n[DEBUG] Output from afpclient.pl:\n" . join("", @volumes) . "\n";

    # CHECK FOR ERRORS
    if ($? == -1) {
        print "Failed to execute afpclient.pl: $!\n";
        return;
    } elsif ($? & 127) {
        printf "afpclient.pl died with signal %d, %s coredump\n",
            ($? & 127), ($? & 128) ? 'with' : 'without';
        return;
    } else {
        my $exit_status = $? >> 8;
        print "[DEBUG] afpclient.pl exited with value $exit_status\n";
    }

    # PARSE THE VOLUME LIST
    my @volume_names;
    foreach my $line (@volumes) {
        # DEBUG: SHOW EACH LINE BEING PARSED
        print "[DEBUG] Parsing line: $line";

        # SKIP THE HEADER LINE AND SEPARATOR
        next if $line =~ /Volume Name|[-]+/;

        # MATCH THE VOLUME NAME BEFORE THE FIRST COLUMN SEPARATOR
        if ($line =~ /^([^\|]+)\|/) {
            my $volume_name = $1;
            $volume_name =~ s/\s+$//;  # Trim trailing whitespace
            push @volume_names, $volume_name;
        }
    }

    # DEBUG: DISPLAY EXTRACTED VOLUME NAMES
    print "[DEBUG] Extracted Volume Names: " . join(", ", @volume_names) . "\n";

    # DISPLAY VOLUMES
    if (@volume_names) {
        print "\nAvailable Volumes on $server->{name}:\n";
        for (my $i = 0; $i < @volume_names; $i++) {
            print "[$i] $volume_names[$i]\n";
        }
    } else {
        print "No volumes available on $server->{name}.\n";
        return;
    }

    # MOUNT PART
    # ALLOW THE USER TO CHOOSE A VOLUME
    my $volume_choice = $term->readline("\nChoose a volume (0-" . ($#volume_names) . "): ");
    if (defined $volume_choice && $volume_choice =~ /^\d+$/ && $volume_choice <= $#volume_names) {
        my $selected_volume = $volume_names[$volume_choice];

        # CONSTRUCT AFP URL FOR THE SELECTED VOLUME WITH afp:/at/
        my $volume_url = "afp:/at/$username:$password\@$server->{host}/$selected_volume";

        print "\n[DEBUG] Final AFP URL for Mounting: $volume_url\n";

        # MOUNT THE VOLUME USING afpmount.pl
        my $mount_point = "/mnt/" . lc($selected_volume);
        $mount_point =~ s/\s+/_/g;

        unless (-d $mount_point) {
            print "\nCreating mount point: $mount_point\n";
            make_path($mount_point) or die "Failed to create mount point: $!\n";
        }

        print "\nMounting volume: $selected_volume at $mount_point using afpmount.pl...\n";
        system("afpmount.pl", "$volume_url", "$mount_point");

        # CHECK THE RESULT AND OFFER OPTIONS
        if ($? == 0) {
            print "\n[INFO] Mounting succeeded at $mount_point.\n";
            my $list_choice = $term->readline("Do you want to list the contents? [y/n]: ");
            if ($list_choice =~ /^y(es)?$/i) {
                system("ls -al $mount_point");
            }
        } else {
            print "\n[ERROR] Mounting failed.\n";
        }
    }
}

# MAIN FLOW
discover_afp_servers_atalk();

if (@discovered_servers) {
    my $selected_server = choose_server();
    if ($selected_server) {
        my $username = $term->readline("Username: ");
        my $password = $term->readline("Password: ");
        show_volumes($selected_server, $username, $password);
    } else {
        print "Invalid selection. Exiting.\n";
    }
} else {
    print "No AppleTalk AFP servers found on the network.\n";
}

