# Linux Chooser

Linux Appletalk Chooser is a Perl script that discovers and connects to AppleTalk AFP (Apple Filing Protocol) servers on a local network. It allows users to browse available servers, list volumes, and mount them locally using afpmount.pl.

## Features

- Discovers AppleTalk AFP servers using NBP (Name Binding Protocol)
- Lists available volumes on selected servers
- Supports user authentication for AFP connections
- Mounts AFP volumes locally for easy access
- Debug logging with Log::Log4perl

## Prerequisites

- Perl 5.x or later
- Required Perl Modules:
  - Net::Atalk::NBP
  - Term::ReadLine
  - URI::Escape
  - File::Path
  - Log::Log4perl
  - diagnostics
- AppleTalk stack configured on the host machine
- afpclient.pl and afpmount.pl scripts for AFP operations
