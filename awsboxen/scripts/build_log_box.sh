#!/bin/sh
#
# Single-box heka collector and log-analyzer thing.

set -e

YUM="yum --assumeyes --enablerepo=epel"
UDO="sudo -u mozsvc"

cd /home/mozsvc

# Install ElasticSearch.

wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.3.tar.gz
tar -zxvf elasticsearch-0.90.3.tar.gz
chown -R mozsvc:mozsvc elasticsearch-0.90.3
rm -f elasticsearch-0.90.3.tar.gz

cat >> /home/mozsvc/circus.ini << EOF
[watcher:elasticsearch]
working_dir=/home/mozsvc/elasticsearch-0.90.3
cmd=bin/elasticsearch
numprocesses=1 
stdout_stream.class = FileStream
stdout_stream.filename = /home/mozsvc/elasticsearch.log
stdout_stream.refresh_time = 0.5
stdout_stream.max_bytes = 1073741824
stdout_stream.backup_count = 3
stderr_stream.class = StdoutStream

[env:elasticsearch]
ES_HEAP_SIZE = 32m
EOF

# Install Kibana.

wget https://github.com/elasticsearch/kibana/archive/master.tar.gz
mv master.tar.gz kibana-master.tar.gz
mkdir kibana-master
cd ./kibana-master
tar -zxvf ../kibana-master.tar.gz
cd ../
chown -R mozsvc:mozsvc ./kibana-master

# Install heka.
# Wow, an RPM!  Awesome.

wget https://people.mozilla.com/~rmiller/heka/heka-0_4_0-2013-08-16-amd64.rpm
$YUM install heka-0_4_0-2013-08-16-amd64.rpm
rm -f heka-0_4_0-2013-08-16-amd64.rpm

# XXX TODO: get this working
#sudo /sbin/chkconfig hekad on
#sudo /sbin/service hekad start
