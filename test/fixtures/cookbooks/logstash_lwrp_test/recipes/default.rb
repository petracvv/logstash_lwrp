openjdk_install '11'

include_recipe 'rsyslog::client'

include_recipe 'elasticsearch'
es_conf = resources('elasticsearch_configure[elasticsearch]')
es_conf.allocated_memory '128m'
es_svc = resources('elasticsearch_service[elasticsearch]')
es_svc.service_actions [:enable, :start]

# Debian 8 only has java-8 in backports
if platform_family?('debian') && node['platform_version'] =~ /^8/

  bash 'Enable backports for java-8' do
    code <<-EOH
    sed -i '/jessie-updates/d' /etc/apt/sources.list
    echo -e "deb http://archive.debian.org/debian/ jessie-backports main contrib non-free" >> /etc/apt/sources.list
    echo -e "deb-src http://archive.debian.org/debian/ jessie-backports main contrib non-free" >> /etc/apt/sources.list
    echo -e "Package: openjdk* openjre* *java*\nPin: release a=jessie-backports\nPin-Priority: 900\n" >> /etc/apt/preferences
    echo -e "Acquire::Check-Valid-Until no;" >> /etc/apt/apt.conf.d/99no-check-valid-until
    EOH
    not_if 'grep jessie-backports /etc/apt/sources.list'
  end.run_action(:run)

  package 'apt-transport-https' do
    action :nothing
  end.run_action(:install)
end

if platform_family?('debian')
  apt_update 'update' do
    action :update
  end
end

logstash_install 'kitchen' do
  version '7.1.0'
  action :upgrade
end

logstash_config 'kitchen' do
  pipeline_defaults(
    'queue.type' => 'persisted',
    'config.reload.automatic' => 'true'
  )
  action :create
end

logstash_pipeline 'main' do
  instance 'kitchen'
  pipeline_workers 1
  config_templates %w( input_syslog.conf.erb output_elasticsearch.conf.erb output_stdout.conf.erb)
  action :create
end

logstash_pipeline 'testing' do
  instance 'kitchen'
  pipeline_workers 1
  config_templates %w( logstash-sample.conf.erb )
  config_template_variables(
    'inputID' => 'SampleTest-Input'
  )
  action :create
end

logstash_pipeline 'string' do
  instance 'kitchen'
  pipeline_workers 1
  config_string 'input { generator {} } filter { sleep { time => 1 } } output { stdout { codec => dots } }'
  pipeline_settings(
    'queue.type' => 'memory'
  )
  action :create
end

logstash_service 'kitchen' do
  xms '256M'
  xmx '256M'
  action [:start, :enable]
end
