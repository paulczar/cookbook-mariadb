Vagrant.require_plugin "vagrant-berkshelf"
Vagrant.require_plugin "vagrant-chef-zero"
Vagrant.require_plugin "vagrant-omnibus"

Vagrant.configure("2") do |config|
  # Berkshelf plugin configuration
  config.berkshelf.enabled = true

  # Chef-Zero plugin configuration
  config.chef_zero.enabled = true
  config.chef_zero.chef_repo_path = "."

  # Omnibus plugin configuration
  config.omnibus.chef_version = '11.8.0'

  chef_json = {
        mariadb: {
          server_root_password: 'ilovestrongpasswords',
          server_debian_password: 'ilovestrongpasswords',
          server_repl_password: 'ilovestrongpasswords',
          server: {
            galera: {
              interface: 'eth1'
            }
          }
        },
        wsrep: {
          password: 'ilovestrongpasswords',
          sst_receive_interface: 'eth1'
        }
  }

  config.vm.box = "opscode-ubuntu-12.04"
  config.vm.box_url = "https://opscode-vm-bento.s3.amazonaws.com/vagrant/opscode_ubuntu-12.04_provisionerless.box"

  # Regular Node
  config.vm.define :galera3 do |galera3|
    galera3.vm.hostname = "galera3"
    galera3.vm.network "private_network", ip: "33.33.33.63"
    galera3.vm.provision :chef_client do |chef|
      #chef.log_level = :debug
      chef.json = chef_json
      chef.run_list = %w{ role[galera] }
    end
  end

  # Regular Node
  config.vm.define :galera2 do |galera2|
    galera2.vm.hostname = "galera2"
    galera2.vm.network "private_network", ip: "33.33.33.62"
    galera2.vm.provision :chef_client do |chef|
      #chef.log_level = :debug
      chef.json = chef_json
      chef.run_list = %w{ role[galera] }
    end
  end

  # Reference Node
  config.vm.define :galera1 do |galera1|
    galera1.vm.hostname = "galera1"
    galera1.vm.network "private_network", ip: "33.33.33.61"
    galera1.vm.provision :chef_client do |chef|
      #chef.log_level = :debug
      chef.json = chef_json
      chef.run_list = %w{ role[galera-reference] }
    end
  end

#  # regular node
#  config.vm.define :galera4 do |galera4|
#    galera4.vm.hostname = "galera4"
#    galera4.vm.network "private_network", ip: "33.33.33.64"
#    galera4.vm.provision :chef_client do |chef|
#      #chef.log_level = :debug
#      chef.json = chef_json
#      chef.run_list = %w{ role[galera] }
#    end
#  end

end
