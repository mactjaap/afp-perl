#!/usr/bin/env perl

# discover AFP servers in your network.

use strict;
use warnings;
use utf8;
use Encode;

# Ensure UTF-8 output
binmode STDOUT, ":utf8";

# Initialize Log::Log4perl to suppress warnings
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);  # Only log errors

use Net::Bonjour;
use Net::AFP::TCP;
use Data::Dumper;
use Carp;
use Getopt::Long;
use Pod::Usage;

# Define default fields to display
my @default_fields = qw(ServerName UTF8ServerName MachineType AFPVersions UAMs NetworkAddresses);
my @fields_to_display;
my $help = 0;

# Parse command-line options
GetOptions(
    'fields|f=s' => \@fields_to_display,  # Accept a comma-separated string
    'help|h'     => \$help,               # Display help
) or pod2usage(2);

# Display help if requested
if ($help) {
    pod2usage({ -verbose => 2, -exitval => 0 });
}

# If no fields are specified, use the default fields
@fields_to_display = @default_fields unless @fields_to_display;

# Split comma-separated fields into an array
if (@fields_to_display && $fields_to_display[0] =~ /,/) {
    @fields_to_display = split(/,/, $fields_to_display[0]);
}

# Check for AppleTalk support
my $has_atalk = 0;
eval {
    require Net::Atalk::NBP;
    require Net::AFP::Atalk;
} and do {
    Net::Atalk::NBP->import();
    Net::AFP::Atalk->import();
    $has_atalk = 1;
};

# Discover AFP services over TCP (mDNS)
my $mdns = new Net::Bonjour('afpovertcp', 'tcp');
$mdns->discover();

# Track processed hosts to avoid duplicates
my %processed_hosts;

foreach my $entry ($mdns->entries()) {
    my $hostname = $entry->name();

    # Skip if this host has already been processed
    next if exists $processed_hosts{$hostname};
    $processed_hosts{$hostname} = 1;

    print "For host $hostname:\n";
    my $srvInfo;
    my $rc = Net::AFP::TCP->GetStatus($entry->address(), $entry->port(), \$srvInfo);
    display_fields($srvInfo);
}

# Exit if AppleTalk is not available
exit(0) unless $has_atalk;

# Discover AFP services over AppleTalk
my @results;
eval {
    @results = NBPLookup(undef, 'AFPServer');
} or carp('AppleTalk stack probably out of order');

foreach my $entry (@results) {
    my $hostname = $entry->[3];

    # Skip if this host has already been processed
    next if exists $processed_hosts{$hostname};
    $processed_hosts{$hostname} = 1;

    print "For host $hostname:\n";
    my $srvInfo;
    my $rc = Net::AFP::Atalk->GetStatus($entry->[0], $entry->[1], \$srvInfo);
    display_fields($srvInfo);
}

# Helper function to display selected fields
sub display_fields {
    my ($srvInfo) = @_;
    foreach my $field (@fields_to_display) {
        if (exists $srvInfo->{$field}) {
            print "$field: ";
            if (ref($srvInfo->{$field}) eq 'ARRAY') {
                if ($field eq 'NetworkAddresses') {
                    print "\n";
                    for my $addr (@{$srvInfo->{$field}}) {
                        if ($addr->{family} == 2) {
                            print "  - IPv4 Address: $addr->{address}\n";
                        } elsif ($addr->{family} == 5) {
                            print "  - AppleTalk Address: $addr->{address} (Port: $addr->{port})\n";
                        } else {
                            print "  - Unknown Address Family: $addr->{address}\n";
                        }
                    }
                } else {
                    print join(", ", @{$srvInfo->{$field}}), "\n";
                }
            } elsif (ref($srvInfo->{$field}) eq 'HASH') {
                print Dumper($srvInfo->{$field});
            } else {
                my $output_value = $srvInfo->{$field};
                if ($field eq 'UTF8ServerName') {
                    # Ensure it's properly decoded without breaking valid UTF-8 strings
                    $output_value = Encode::decode("UTF-8", $output_value) unless Encode::is_utf8($output_value);
                }
                print $output_value, "\n";
            }
        } else {
            print "$field: (Not available)\n";
        }
    }
    print "\n";
}

__END__

=head1 NAME

afp-discover.pl - Discover and display AFP (Apple Filing Protocol) service information.

=head1 SYNOPSIS

afp-discover.pl [options]

Options:
    -f, --fields <field1,field2,...>  Specify fields to display (comma-separated).
    -h, --help                        Display this help message.

=head1 DESCRIPTION

This script discovers AFP services over TCP (mDNS) and optionally over AppleTalk (if supported).
It displays information about the discovered services based on the specified fields.

=head1 OPTIONS

=over 4

=item B<-f, --fields> <field1,field2,...>

Specify the fields to display. Multiple fields can be specified as a comma-separated list.

=item B<-h, --help>

Display this help message.

=back

=head1 EXAMPLES

Discover AFP services and display default fields:

    ./afp-discover.pl

Discover AFP services and display specific fields:

    ./afp-discover.pl --fields ServerName,AFPVersions

=cut
