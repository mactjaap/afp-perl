#!/usr/bin/bash
# REPO6

set -e  # Exit on any error

echo "Starting installation process for AFP Client..."

# Install system dependencies
echo "Installing system dependencies..."
apt update > /dev/null
apt install -y libkrb5-dev libfuse-dev libreadline-dev build-essential git perl-doc cpanminus libfile-extattr-perl > /dev/null

# Clone and build afp-perl
echo "Cloning and building afp-perl..."
rm -fr afp-perl
git clone https://github.com/demonfoo/afp-perl.git > /dev/null
cd afp-perl
cpanm --quiet --notest Class::InsideOut Fuse Fuse::Class Log::Dispatch Log::Log4perl Readonly String::Escape Text::Glob Net::Bonjour > /dev/null
perl Makefile.PL > /dev/null
make > /dev/null
make install > /dev/null

# Clone and build atalk-perl
echo "Cloning and building atalk-perl..."
cd ..
rm -fr atalk-perl
git clone https://github.com/demonfoo/atalk-perl.git > /dev/null
cd atalk-perl
perl Makefile.PL > /dev/null
make > /dev/null
make install > /dev/null

# Install additional Perl modules
echo "Installing additional Perl modules..."
cpanm --quiet --notest Crypt::Mode::CBC Modern::Perl GSSAPI Params::Validate Term::ReadPassword Term::ReadLine::Gnu > /dev/null

# Verify Perl modules
echo "Verifying Perl modules..."
perl -MGSSAPI -e 'print "GSSAPI module is available\n"' > /dev/null
perl -MTerm::ReadPassword -e 'print "Term::ReadPassword module is available\n"' > /dev/null
perl -MTerm::ReadLine -e 'print "Term::ReadLine backend: ", Term::ReadLine->ReadLine, "\n"' > /dev/null

# Set environment variable for Term::ReadLine::Gnu
export PERL_RL=Gnu

# Install example scripts to /usr/local/bin
echo "Copying AFP example scripts to /usr/local/bin..."
cp ../afp-perl/examples/* /usr/local/bin/ > /dev/null

# Install Chooser script to /usr/local/bin
echo "Copying Chooser scripts t /usr/local/bin..."
cp ../afp-perl/CHOOSER/*.pl /usr/local/bin/ > /dev/null

# Install AFP-Discover script to /usr/local/bin
echo "Copying AFP-Discover script to /usr/local/bin..."
cp ../afp-perl/AFP-DISCOVER/*.pl /usr/local/bin/ > /dev/null

echo "Making chooser.pl executable..."
chmod +x /usr/local/bin/chooser.pl > /dev/null

echo "Making chooser.pl executable..."
chmod +x /usr/local/bin/afp-discover.pl > /dev/null

echo "Making afp_acl.pl executable..."
chmod +x /usr/local/bin/afp_acl.pl > /dev/null

echo "Making afp_chpass.pl executable..."
chmod +x /usr/local/bin/afp_chpass.pl > /dev/null

echo "Making afpclient.pl executable..."
chmod +x /usr/local/bin/afpclient.pl > /dev/null

echo "Making afp-mdns-test.pl executable..."
chmod +x /usr/local/bin/afp-mdns-test.pl > /dev/null

echo "Making afpmount.pl executable..."
chmod +x /usr/local/bin/afpmount.pl > /dev/null

echo "All example scripts are copied and made executable."
