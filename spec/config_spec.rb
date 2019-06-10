require 'spec_helper'

describe 'logstash_config' do
  step_into :logstash_config
  platform 'ubuntu'
  automatic_attributes['hostname'] = 'logstash-test'

  context 'with default options' do
    recipe do
      logstash_install 'test'
      logstash_config 'test'
      logstash_service 'test'
    end

    it do
      is_expected.to create_template('/opt/logstash_test/config/logstash.yml').with(
        user: 'logstash',
        group: 'logstash',
        mode: '0640'
      )
    end

    it do
      is_expected.to render_file('/opt/logstash_test/config/logstash.yml').with_content { |content|
        expect(content).to include('node.name: logstash-test')
        expect(content).to include('path.data: /opt/logstash_test/data')
        expect(content).to include('path.logs: /opt/logstash_test/logs')
        expect(content).to include('log.level: info')
        expect(content).to include('log.format: plain')
      }
    end
  end
end
