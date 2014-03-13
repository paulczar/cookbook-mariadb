require_relative 'spec_helper'

describe 'mariadb::server' do
  include_context 'stubs-common'
  let(:ubuntu_1204_run) { ChefSpec::Runner.new(::UBUNTU_OPTS).converge(described_recipe) }

  it 'includes _server_debian on ubuntu1204' do
    expect(ubuntu_1204_run).to include_recipe('mariadb::_server_debian')
  end
end
