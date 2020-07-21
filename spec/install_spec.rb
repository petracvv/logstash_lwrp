require 'spec_helper'

describe 'logstash_install' do
  step_into :logstash_install
  platform 'ubuntu'

  automatic_attributes['hostname'] = 'logstash-test'

  before do
    allow(Dir).to receive(:empty?).and_call_original
    allow(Dir).to receive(:empty?).with('/opt/logstash_test_7_1_0/').and_return(true)
  end

  context 'with default options' do
    recipe do
      logstash_install 'test'
      logstash_config 'test'
      logstash_service 'test'
    end

    it { is_expected.to install_package('tar') }

    it { is_expected.to create_group('logstash') }

    it do
      is_expected.to create_user('logstash').with(
        gid: 'logstash',
        shell: '/sbin/nologin',
        system: true
      )
    end

    it do
      is_expected.to create_directory('/opt/logstash_test_7_1_0/').with(
        owner: 'logstash',
        group: 'logstash',
        mode: '0750',
        recursive: true
      )
    end

    it { is_expected.to create_remote_file("#{Chef::Config['file_cache_path']}/logstash-7.1.0.tar.gz") }

    it { expect(chef_run.remote_file("#{Chef::Config['file_cache_path']}/logstash-7.1.0.tar.gz")).to notify('execute[extract logstash tarball]').to(:run).immediately }

    it { expect(chef_run.execute('chown logstash installation as logstash')).to subscribe_to('execute[extract logstash tarball]').on(:run).immediately }

    it { is_expected.to create_link('/opt/logstash_test').with_to('/opt/logstash_test_7_1_0/') }
  end

  context 'with upgrade action' do
    before do
      allow(File).to receive(:symlink?).and_call_original
      allow(File).to receive(:symlink?).with('/opt/logstash_test').and_return(true)

      allow(File).to receive(:realpath).and_call_original
      allow(File).to receive(:realpath).with('/opt/logstash_test').and_return('/opt/logstash_test_6_8_0')
    end

    recipe do
      logstash_install 'test' do
        action :upgrade
      end
      logstash_config 'test'
      logstash_service 'test'
    end

    it { expect(chef_run.notify_group('stop logstash service before upgrade')).to notify('logstash_service[test]').to(:stop).immediately }

    it { is_expected.to run_ruby_block('Install new version') }

    it do
      is_expected.to run_execute('copy persistent data from old install').with(
        command: 'cp -a /opt/logstash_test_6_8_0/data /opt/logstash_test/',
        user: 'logstash'
      )
    end
  end
end
