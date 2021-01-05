require 'spec_helper'

describe 'logstash_pipeline' do
  step_into :logstash_pipeline
  platform 'ubuntu'

  context 'with config_templates' do
    recipe do
      logstash_install 'test'
      logstash_pipeline 'example1' do
        instance 'test'
        config_templates %w( input_syslog.conf.erb )
      end
      logstash_service 'test'
    end

    it do
      is_expected.to create_directory('/opt/logstash_test/pipelines').with(
        owner: 'logstash',
        group: 'logstash',
        mode: '0550'
      )

      is_expected.to create_directory('/opt/logstash_test/pipelines/example1').with(
        owner: 'logstash',
        group: 'logstash',
        mode: '0550'
      )
    end

    it do
      is_expected.to create_template('/opt/logstash_test/pipelines/example1/input_syslog.conf').with(
        source: 'input_syslog.conf.erb',
        owner: 'logstash',
        group: 'logstash',
        mode: '0640'
      )
    end

    it do
      is_expected.to render_file('/opt/logstash_test/config/pipelines.yml').with_content { |content|
        expect(content).to include('pipeline.id: example1')
        expect(content).to include('pipeline.workers: 1')
        expect(content).to include('path.config: "/opt/logstash_test/pipelines/example1"')
      }
    end

    it { expect(chef_run.template('/opt/logstash_test/config/pipelines.yml')).to notify('execute[verify logstash config]').to(:run) }
    it { expect(chef_run.execute('verify logstash config')).to notify('logstash_service[test]').to(:restart).immediately }
  end

  context 'with config_string' do
    recipe do
      logstash_install 'test'
      logstash_pipeline 'example2' do
        instance 'test'
        config_string 'input { generator {} } filter { sleep { time => 1 } } output { stdout { codec => dots } }'
      end
      logstash_service 'test'
    end

    it do
      is_expected.to render_file('/opt/logstash_test/config/pipelines.yml').with_content { |content|
        expect(content).to include('pipeline.id: example2')
        expect(content).to include('pipeline.workers: 1')
        expect(content).to include('config.string: input { generator {} } filter { sleep { time => 1 } } output { stdout')
        expect(content).to include('{ codec => dots } }')
      }
    end

    it { expect(chef_run.template('/opt/logstash_test/config/pipelines.yml')).to notify('execute[verify logstash config]').to(:run) }
    it { expect(chef_run.execute('verify logstash config')).to notify('logstash_service[test]').to(:restart).immediately }
  end

  context 'with pipeline_settings' do
    recipe do
      logstash_install 'test'
      logstash_pipeline 'example3' do
        instance 'test'
        config_templates %w( input_syslog.conf.erb )
        pipeline_settings(
          'dead_letter_queue.enable' => true,
          'queue.max_events' => 100
        )
      end
      logstash_service 'test'
    end

    it do
      is_expected.to render_file('/opt/logstash_test/config/pipelines.yml').with_content { |content|
        expect(content).to include('pipeline.id: example3')
        expect(content).to include('pipeline.workers: 1')
        expect(content).to include('dead_letter_queue.enable: true')
        expect(content).to include('queue.max_events: 100')
      }
    end
  end

  context 'with multiple pipelines defined' do
    recipe do
      logstash_install 'test'
      logstash_pipeline 'example4' do
        instance 'test'
        config_templates %w( input_syslog.conf.erb )
      end
      logstash_pipeline 'example5' do
        instance 'test'
        config_templates %w( input_test.conf.erb )
      end
      logstash_service 'test'
    end

    it do
      is_expected.to render_file('/opt/logstash_test/config/pipelines.yml').with_content { |content|
        expect(content).to include('pipeline.id: example4')
        expect(content).to include('pipeline.id: example5')
      }
    end
  end
end
