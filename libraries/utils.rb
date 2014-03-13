#!/usr/bin/env ruby

module MG
  def check_state_attr(server, attrs = {})
    attrib = attrs['attr']
    a_key = attrs['key']
    a_var = attrs['var']
    a_time = attrs['timeout']
    sttime = attrs['sttime']
    until server.attribute?(attrib) && server[attrib].key?(a_key) && server[attrib][a_key] == a_var
      if (Time.now.to_f - sttime) >= a_time
        Chef::Application.fatal! "Timeout exceeded while node #{server.name} syncing.."
      else
        Chef::Log.info "Waiting while node #{server.name} syncing.."
        sleep 10
        if Chef::Config[:solo]
          server = node['galera']['nodes'][0]

        else
          server = search(:node, "name:#{server.name} AND chef_environment:#{node.chef_environment}")[0]
        end
      end
    end
    true
  end

  def initialize_cluster(pid, address)
    Chef::Log.info "Starting MariaDB to create initial cluster - #{address}"
    system('service mysql stop && echo stopping running mysql service')
    cmd = "mysqld --pid-file=#{pid} --wsrep_cluster_address=#{address} 2>/var/log/mysql/init.log > /var/log/mysql/init.log &"
    system(cmd)
    sleep 10
  end

  def check_sync_status(password)
    sttime = Time.now.to_f
    cmd = "/usr/bin/mysql -uroot -p#{password} -Nbe \"show status like 'wsrep_local_state_comment'\" | /bin/grep -q Synced"
      until system(cmd)
        if (Time.now.to_f - sttime) >= 300
          Chef::Application.fatal! 'Timeout exceeded while waiting for sync'
          exit 1
        else
          Chef::Log.info 'Waiting for sync..'
          sleep 10
        end
      end
      Chef::Log.info 'Sync is good.'
  end
end

class Chef::Recipe
  include MG
end
class Chef::Resource::Template
  include MG
end
class Chef::Resource::RubyBlock
  include MG
end
