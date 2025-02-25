This Perl script is designed to discover and display information about AFP (Apple Filing Protocol) services over both TCP (using mDNS) and, if available, AppleTalk.

- It starts by setting up UTF-8 output and configuring logging to only show errors.
- The script uses several modules for networking and service discovery, including `Net::Bonjour` for mDNS (TCP) and, if available, `Net::Atalk::NBP` and `Net::AFP::Atalk` for AppleTalk.
- It parses command-line options to allow the user to specify which fields to display (`--fields` or `-f`) or to show help (`--help` or `-h`).
- If no specific fields are requested, it defaults to showing the following: ServerName, UTF8ServerName, MachineType, AFPVersions, UAMs, and NetworkAddresses.
- It first discovers AFP services over mDNS (TCP), avoiding duplicate hosts using a hash.
- If AppleTalk support is available, it also discovers AFP services over AppleTalk.
- For each discovered host, it retrieves detailed service information and displays only the requested fields.
- Special handling is done for UTF-8 strings to ensure correct encoding.
- It checks and displays network addresses (IPv4 and AppleTalk) in a user-friendly format.
- The `display_fields` subroutine is responsible for formatting and printing the output.

This script is useful for network administrators or users who want to discover AFP servers on their local network.
