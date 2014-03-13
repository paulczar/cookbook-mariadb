#
# Cookbook Name:: mariadb
# Attributes:: server-galera
#
# Copyright 2008-2013, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

default['mariadb']['server']['galera']['interface'] = 'eth0'

case node['platform']
when 'centos', 'redhat', 'fedora', 'suse', 'scientific', 'amazon'
  default['wsrep']['provider'] = '/usr/lib64/galera/libgalera_smm.so'
else
  default['wsrep']['provider'] = '/usr/lib/galera/libgalera_smm.so'
end

# Define galera pid's
default['galera']['mysqld_pid'] = '/var/run/cluster_init.pid'
default['galera']['rsync_pid'] = '/var/lib/mysql//rsync_sst.pid'

# Define timeouts
default['galera']['global_timer'] = 300
default['galera']['local_timer'] = 60

# The name of the Chef role for servers involved in a Galera cluster
# When writing the wsrep_urls, the recipe searches for nodes that
# are assigned this Chef role and have a matching wsrep_cluster_name
default['galera']['chef_role'] = 'galera'

# The name of the Chef role for servers that are the reference node
# in a cluster. The reference node is the first server in a cluster
# started and, if taken out of load-balancing rotation, can serve
# as the node that is most easily used as a backup and conflict resolver.
default['galera']['reference_node_chef_role'] = 'galera-reference'

# Sets debug logging in the WSREP adapter
default['wsrep']['debug'] = false

# The user of the MySQL user that will handle WSREP SST communication.
# Note that this user's password is set via secure_password in the
# server_galera recipe, like other passwords are set in the MySQL
# cookbooks.
default['wsrep']['user'] = 'wsrep_sst'

# Port that SST communication will go over.
default['wsrep']['port'] = 4567

# Options specific to the WSREP provider.
default['wsrep']['provider_options'] = ''

# Logical cluster name. Should be the same for all nodes in the cluster.
default['wsrep']['cluster_name'] = 'my_galera_cluster'

# How many threads will process writesets from other nodes
# (more than one untested)
default['wsrep']['slave_threads'] = 1

# Generate fake primary keys for non-PK tables (required for multi-master
# and parallel applying operation)
default['wsrep']['certify_non_pk'] = 1

# Maximum number of rows in write set
default['wsrep']['max_ws_rows'] = 131_072

# Maximum size of write set
default['wsrep']['max_ws_size'] = 1_073_741_824

# how many times to retry deadlocked autocommits
default['wsrep']['retry_autocommit'] = 1

# change auto_increment_increment and auto_increment_offset automatically
default['wsrep']['auto_increment_control'] = 1

# enable "strictly synchronous" semantics for read operations
default['wsrep']['casual_reads'] = 0

# State Snapshot Transfer method. Note that if you set this
# to mysqldump, you will need to set wsrep_user above to root.
default['wsrep']['sst_method'] = 'rsync'

# Interface on this node to receive SST communication.
default['wsrep']['sst_receive_interface'] = 'eth0'
