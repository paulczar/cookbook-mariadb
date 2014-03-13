# Encoding: utf-8
require 'chefspec'
require 'chefspec/berkshelf'
require 'chefspec/server'
require 'chef/application'

::LOG_LEVEL = :fatal

::REDHAT_OPTS = {
  platform:   'redhat',
  version:    '6.4',
  log_level:  ::LOG_LEVEL,
  provider:  'none'
}
::UBUNTU_OPTS = {
  platform:  'ubuntu',
  version:   '12.04',
  log_level: ::LOG_LEVEL,
  provider:  'none'
}

shared_context 'stubs-common' do
  before do
    Chef::Application.stub(:fatal!).and_return('fatal')
    stub_command("/usr/bin/mysql -u root -e 'show databases;'").and_return('')
    stub_command("[ '/var/lib/mysql' != /var/lib/mysql ]").and_return('')
    stub_command('[ `stat -c %h /var/lib/mysql` -eq 2 ]').and_return(true)
  end
end

shared_context 'stubs-vault' do
  def chef_vault_mock(vault, item, value)
    ChefVault::Item.stub(:load).with(vault, item).and_return(value)
  end
  before do
    chef_vault_mock(
      'cloud_credentials',
      'username',
      id:                 'username',
      rackspace_username: 'username',
      rackspace_api_key:  'api_key'
    )
  end
end

# at_exit { ChefSpec::Coverage.report! }

shared_examples 'example' do
#  it 'does not include example recipe by default' do
#    expect(chef_run).not_to include_recipe('example::default')
#  end
end
