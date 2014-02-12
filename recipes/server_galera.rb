#
# Cookbook Name:: mariadb
# Recipe:: default
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

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
::Chef::Recipe.send(:include, Opscode::Mysql::Helpers)

include_recipe 'mariadb::client'

if Chef::Config[:solo]
  missing_attrs = %w{
    server_debian_password
    server_root_password
    server_repl_password
  }.select { |attr| node['mariadb'][attr].nil? }.map { |attr| "node['mariadb']['#{attr}']" }

  if !missing_attrs.empty? or node["wsrep"]["password"].nil?
    Chef::Application.fatal! "You must set #{missing_attrs.join(', ')} in chef-solo mode." \
    " For more information, see https://github.com/joerocklin/chef-mariadb#chef-solo-note"
  end

  if node['galera']['nodes'].empty?
    fail_msg = "You must set node['galera']['nodes'] to a list of IP addresses or hostnames for each node in your cluster if you are using Chef Solo"
    Chef::Application.fatal!(fail_msg)
  end
  cluster_addresses = node["galera"]["nodes"]
  # Just assume first node is reference node...
  reference_node = node["galera"]["nodes"][0]

else
  # generate all passwords
  node.set_unless['mariadb']['server_debian_password'] = secure_password
  node.set_unless['mariadb']['server_root_password']   = secure_password
  node.set_unless['mariadb']['server_repl_password']   = secure_password
  node.set_unless['wsrep']['password'] = secure_password

  # SST authentication string. This will be used to send SST to joining nodes.
  # Depends on SST method. For mysqldump method it is wsrep_sst:<wsrep password>
  node.set['wsrep']['sst_auth'] = "#{node['wsrep']['user']}:#{node['wsrep']['password']}"
  node.save

  galera_role = node["galera"]["chef_role"]
  galera_reference_role = node["galera"]["reference_node_chef_role"]
  cluster_name = node["wsrep"]["cluster_name"]
  cluster_addresses = []

  ::Chef::Log.info "Searching for nodes having role '#{galera_role}' and cluster name '#{cluster_name}'"
  # Shorter query format (alff), also reduce result count by chef_environment
  results = search(:node, "role:#{galera_role} AND wsrep_cluster_name:#{cluster_name} AND chef_environment:#{node.chef_environment}")
  galera_nodes = results

  if results.empty?
    ::Chef::Application.fatal!("Searched for role #{galera_role} and cluster name #{cluster_name} found no nodes. Exiting.")
  elsif results.size < 3
    ::Chef::Log.info("You need at least three Galera nodes in the cluster. Found #{results.size}.")
    got_three = false
  else
    ::Chef::Log.info "Found #{results.size} nodes in cluster #{cluster_name}."
    got_three = true
    # Now we grab each node's IP address and store in our cluster_addresses array
    results.each do |result|
      if result['mariadb']['server']['galera']['interface']
        # node["network"]["interfaces"][iface_name]["addresses"].keys[1]
        address = result['network']['interfaces'][result['mariadb']['server']['galera']['interface']]['addresses'].keys[1]
      else
        address = result['mariadb']['bind_address']
      end
      unless result.name == node.name
        ::Chef::Log.info "Adding #{address} to list of cluster addresses in cluster '#{cluster_name}'."
        cluster_addresses << address
      end
    end

    ::Chef::Log.info "Searching for reference node having role '#{galera_reference_role}' in cluster '#{cluster_name}'"
    results = search(:node, "role:#{galera_reference_role} AND wsrep_cluster_name:#{cluster_name} AND chef_environment:#{node.chef_environment}")
    if results.empty?
      ::Chef::Application.fatal!("Could not find node with reference role. Exiting.")
    elsif results.size != 1
      ::Chef::Application.fatal!("Can only be a single node in cluster '#{cluster_name}' with reference role. Found #{results.size}. Exiting.")
    else
      reference_node = results[0]
      ::Chef::Log.info "Reference node found - #{reference_node}"
    end
  end
  node.save
end

# Compose list of galera ip's
wsrep_ip_list = "gcomm://" + cluster_addresses.join(',')

# The following variables in the my.cnf MUST BE set
# this way for Galera to work properly.
node.set['mariadb']['tunable']['query_cache_size'] = '0'
node.set['mariadb']['tunable']['binlog_format'] = 'ROW'
node.set['mariadb']['tunable']['default_storage_engine'] = 'innodb'
node.set['mariadb']['tunable']['innodb_autoinc_lock_mode'] = '2'
node.set['mariadb']['tunable']['innodb_locks_unsafe_for_binlog'] = '1'
node.set['mariadb']['tunable']['innodb_flush_log_at_trx_commit'] = '2'
#node.set['mariadb']['tunable']['innodb_support_xa'] = false ?? performance ??


case node['platform_family']
when 'debian'
  include_recipe 'mariadb::_server_galera_debian'
end

if got_three

  sst_receive_address = node['network']['interfaces'][node['wsrep']['sst_receive_interface']]['addresses'].keys[1]
  template "#{node['mariadb']['server']['directories']['confd_dir']}/wsrep.cnf" do
    source "wsrep.cnf.erb"
    owner "root"
    group "root"
    mode 00644
    notifies :restart, "service[mysql]"
    variables(
      "sst_receive_address" => sst_receive_address,
      "wsrep_cluster_address" => wsrep_ip_list,
      "wsrep_node_address" => node['mariadb']['bind_address']
    )
  end

  # Set flag that first stage of galera cluster init completed
  ruby_block "Set-initial_replicate-state" do
    block do
      node.set_unless["galera"]["cluster_initial_replicate"] = "ok"
      ::Chef::Log.info "setting initial replicate state to ok"
      node.save
    end
    action :nothing
  end

  # Set final flag that current node have fully working status
  ruby_block "Cluster-ready" do
    block do
      node.set["galera"]["cluster_status"] = "ready"
      node.save
    end
    action :nothing
  end
  # End of block

  # Is this node reference node or not.
  if node.run_list.role_names.include?(galera_reference_role)
    master = true
    ::Chef::Log.info "I am the banana king!"
  else
    master = false
  end

      # Search that all galera nodes finished first stage
      # of galera cluster initialization
      ruby_block "Search-other-galera-mysql-servers" do
        block do
          ::Chef::Log.info "Searching for other servers..."
          galera_nodes.each do |result|
            # Remove reference from check
            if result.run_list.role_names.include?(galera_reference_role)
              next
            end
            hash = {}
            hash["attr"] = "galera"
            hash["key"] = "cluster_initial_replicate"
            hash["var"] = "ok"
            hash["timeout"] = node["galera"]["global_timer"]
            hash["sttime"]=Time.now.to_f
            check_state_attr(result,hash)
          end
        end
        action :nothing
      end

  # Start of galera cluster configuration
  ::Chef::Log.info "local replication state - #{node["galera"]["cluster_initial_replicate"]}"
  unless node["galera"]["cluster_initial_replicate"] == "ok"

    if master

      ruby_block "stop mysql service" do
        block do
          ::Chef::Log.info 'stopping mysql service!  it should not be running right now.'
        end
        notifies :stop, "service[mysql]", :immediately
      end

      wsrep_cluster_address = "gcomm://"

      ruby_block "Initialize-cluster" do
        block do
          initialize_cluster(node['mariadb']['server']['pid_file'],wsrep_cluster_address)
        end
        not_if { File.exist?("node['mariadb']['server']['pid_file']") }
      end

      ruby_block "Check-sync-status" do
        block do
          if check_sync_status(node['mariadb']['server_root_password'])
            node.set["galera"]["sync_status"] = true
            node.set_unless["galera"]["cluster_initial_replicate"] = "ok"
            ::Chef::Log.info "setting initial replicate state to ok"
            node.save
          end
        end

        notifies :create, "ruby_block[Search-other-galera-mysql-servers]", :immediately
      end

      # Check that all non-reference nodes are in operating condition
      ruby_block "Check-cluster-status" do
        block do
          galera_nodes.each do |result|
            # Remove reference from check
            if result.run_list.role_names.include?(galera_reference_role)
              next
            end
            hash = {}
            hash["attr"] = "galera"
            hash["key"] = "cluster_status"
            hash["var"] = "ready"
            hash["timeout"] = 300
            hash["sttime"]=Time.now.to_f
            check_state_attr(result,hash)
          end
        end
      notifies :create, "ruby_block[Cluster-ready]"
      end

    else
      wsrep_cluster_address = wsrep_ip_list

      # immediate restart of mysql
      ruby_block "Restart-mysql-service" do
        block do
          ::Chef::Log.info "restarting mysql service"
        end
        notifies :restart, "service[mysql]", :immediately
      end

      # Waiting for start reference node in cluster mode initialization mode
      ruby_block "Check-master-state" do
        block do
          sttime=Time.now.to_f
          result = reference_node
          until result.attribute?("galera")&&result["galera"].key?("cluster_initial_replicate")&&result["galera"]["cluster_initial_replicate"]=="ok" do
            if (Time.now.to_f-sttime)>=300
              Chef::Log.error "Timeout exceeded while reference node #{result.name} syncing.."
              exit 1
            else
              Chef::Log.info "Waiting while node #{result.name} syncing.."
              sleep 10
              result = search(:node, "name:#{result.name} AND chef_environment:#{node.chef_environment}")[0]
            end
          end
          check_sync_status(node['mariadb']['server_root_password'])
        end
        # Check that all non-reference nodes are synced with reference node
        #notifies :run, "ruby_block[Check-sync-status]", :immediately
        notifies :create, "ruby_block[Set-initial_replicate-state]", :immediately
        notifies :create, "ruby_block[Search-other-galera-mysql-servers]", :immediately
        # Set flag that non-reference node is in operating condition
        notifies :create, "ruby_block[Cluster-ready]"
      end
    end
  end
else
  ::Chef::Log.info("Will not configure Galera replication until you have 3 nodes.")
end