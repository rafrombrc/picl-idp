#!/bin/sh

set -e

YUM="yum --assumeyes --enablerepo=epel"

$YUM update
$YUM install python-pip git openssl-devel python-devel
$YUM install gcc gcc-c++ czmq-devel zeromq nginx

# Add ssh public keys.

git clone https://github.com/mozilla/identity-pubkeys
cd identity-pubkeys
git checkout b63a19a153f631c949e7f6506ad4bf1f258dda69
cat *.pub >> /home/ec2-user/.ssh/authorized_keys
cd ..
rm -rf identity-pubkeys

# Add an unprivileged user as which to run various services.

useradd mozsvc

# Configure circus to run on startup, executing the mozsvc user's circus.ini.
# Additional build steps may add to circus.ini to make their programs run.

python-pip install circus

cd /home/mozsvc
touch circus.ini
chown mozsvc:mozsvc circus.ini

cat > /etc/rc.local << EOF
# Sleep briefly, to give cloud-init a chance to write its config files.
sleep 1m

# Run the mozsvc-user-controlled service processes via circus.
su -l mozsvc -c '/usr/bin/circusd --daemon /home/mozsvc/circus.ini'

exit 0
EOF

# XXX TODO: install and setup a local heka collector, forwarding to logbox.

