#!/bin/sh
#
# Build a webhead node for picl-idp.
#
# This script builds a custom machine setup for running the picl-idp nodejs
# application.  It's running on top of a stack more familiar to the services
# team than the black-box of the awsbox AMI.

set -e

UDO="sudo -u mozsvc"

YUM="yum --assumeyes --enablerepo=epel"
$YUM install nodejs npm gmp gmp-devel

# Grab and build the latest master of picl-idp.
# XXX TODO: technically should use the commit being deployed, but
# I need to teach awsbox how to expose that to the scripts.  Env vars?
# This will eventually be puppetized anyway.

cd /home/mozsvc
$UDO git clone https://github.com/mozilla/picl-idp
cd picl-idp
git checkout -t origin/cassandra-cluster
$UDO npm install

# XXX TODO: write configuration files
#   public_url
#   domain
#   smtp setup
# XXX TODO: generate keypair (to be shared between all webheads!)

# Write a circus config file to run the app with nodejs.
# XXX TODO: multiple nodejs processes per box?
# Circus's socket-sharing thing might be useful here!

cd ../
cat >> circus.ini << EOF
[watcher:keyserver]
working_dir=/home/mozsvc/picl-idp
cmd=node bin/key_server.js
numprocesses = 1
stdout_stream.class = FileStream
stdout_stream.filename = /home/mozsvc/picl-idp/circus.log
stdout_stream.refresh_time = 0.5
stdout_stream.max_bytes = 1073741824
stdout_stream.backup_count = 3
stderr_stream.class = StdoutStream

[env:keyserver]
PORT=8000
CONFIG_FILES=/home/mozsvc/picl-idp/config/production.json,/home/mozsvc/picl-idp/config/cloud_formation.json
EOF

