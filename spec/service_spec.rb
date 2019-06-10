require 'spec_helper'

describe 'logstash_service' do
  step_into :logstash_service
  automatic_attributes['memory']['total'] = '1024'

  recipe do
    logstash_install 'test'
    logstash_service 'test'
  end

  # Focus on systemd for tests
  platform 'ubuntu'

  before do
    allow(Chef::Platform::ServiceHelpers).to receive(:service_resource_providers).and_call_original
    allow(Chef::Platform::ServiceHelpers).to receive(:service_resource_providers).and_return([:systemd])
  end

  context 'when starting service' do
    it do
      is_expected.to create_template('/opt/logstash_test/config/jvm.options').with(
        owner: 'logstash',
        group: 'logstash',
        mode: '0640'
      )
    end

    it do
      is_expected.to render_file('/opt/logstash_test/config/jvm.options').with_content { |content|
        expect(content).to include('Xms614')
        expect(content).to include('Xmx614')
        expect(content).to include('-XX:+UseConcMarkSweepGC')
        expect(content).to include('-XX:CMSInitiatingOccupancyFraction=75')
        expect(content).to include('-XX:+UseCMSInitiatingOccupancyOnly')
        expect(content).to include('-Djava.awt.headless=true')
        expect(content).to include('-Dfile.encoding=UTF-8')
        expect(content).to include('-Djruby.compile.invokedynamic=true')
        expect(content).to include('-Djruby.jit.threshold=0')
        expect(content).to include('-XX:+HeapDumpOnOutOfMemoryError')
        expect(content).to include('-Djava.security.egd=file:/dev/urandom')
      }
    end

    context 'with upstream unit file' do
      it do
        is_expected.to create_template('/opt/logstash_test/config/startup.options').with(
          owner: 'logstash',
          group: 'logstash',
          mode: '0640'
        )
      end

      it do
        is_expected.to render_file('/opt/logstash_test/config/startup.options').with_content { |content|
          expect(content).to include('JAVACMD=/usr/bin/java')
          expect(content).to include('LS_HOME=/opt/logstash_test')
          expect(content).to include('LS_SETTINGS_DIR=/opt/logstash_test/config')
          expect(content).to include('LS_OPTS="--path.settings /opt/logstash_test/config"')
          expect(content).to include('LS_PIDFILE=/var/run/logstash_test.pid')
          expect(content).to include('LS_USER=logstash')
          expect(content).to include('LS_GROUP=logstash')
          expect(content).to include('LS_GC_LOG_FILE=/opt/logstash_test/logs/logstash_test_gc.log')
          expect(content).to include('LS_OPEN_FILES=16384')
          expect(content).to include('LS_NICE=19')
          expect(content).to include('SERVICE_NAME="logstash_test"')
          expect(content).to include('SERVICE_DESCRIPTION="logstash"')
        }
      end

      it { expect(chef_run.template('/opt/logstash_test/config/startup.options')).to notify('execute[Generate service file]').to(:run).immediately }
      it { expect(chef_run.template('/opt/logstash_test/config/startup.options')).to notify('logstash_service[test]').to(:restart) }
    end

    context 'with custom unit file' do
      recipe do
        logstash_install 'test'
        logstash_service 'test' do
          systemd_unit_content <<-EOU.gsub(/^\s+/, '')
          [Unit]
          Description=logstash

          [Service]
          Type=simpleUser=logstash
          Group=logstash
          # Load env vars from /etc/default/ and /etc/sysconfig/ if they exist.
          # Prefixing the path with '-' makes it try to load, but if the file doesn't
          # exist, it continues onward.
          EnvironmentFile=-/etc/default/logstash_test
          EnvironmentFile=-/etc/sysconfig/logstash_test
          ExecStart=/opt/logstash_test/bin/logstash "--path.settings" "/opt/logstash_test/config"
          Restart=always
          WorkingDirectory=/
          Nice=19
          LimitNOFILE=16384

          [Install]
          WantedBy=multi-user.target
          EOU
        end
      end

      it { is_expected.to create_systemd_unit('logstash_test.service') }
    end

    it { is_expected.to start_service('logstash_test').with(provider: Chef::Provider::Service::Systemd) }
  end

  context 'when stopping service' do
    recipe do
      logstash_install 'test'
      logstash_service 'test' do
        action :stop
      end
    end
    it { is_expected.to stop_service('logstash_test') }
  end

  context 'when restarting service' do
    recipe do
      logstash_install 'test'
      logstash_service 'test' do
        action :restart
      end
    end
    it { is_expected.to restart_service('logstash_test') }
  end

  context 'when enabling service' do
    recipe do
      logstash_install 'test'
      logstash_service 'test' do
        action :enable
      end
    end
    it { is_expected.to enable_service('logstash_test') }
  end
end
