include_recipe 'elasticsearch'
es_conf = resources('elasticsearch_configure[elasticsearch]')
es_conf.allocated_memory '128m'
es_svc = resources('elasticsearch_service[elasticsearch]')
es_svc.service_actions [:enable, :start]

# Debian 8 only has java-8 in backports
bash 'Enable backports for java-8' do
  code <<-EOH
  echo -e "deb http://ftp.us.debian.org/debian/ jessie-backports main" >> /etc/apt/sources.list
  echo -e "Package: openjdk* openjre* *java*\nPin: release a=jessie-backports\nPin-Priority: 900\n" >> /etc/apt/preferences
  EOH
  only_if { node['platform_family'] == 'debian' && node['platform_version'] =~ /^8/ }
  not_if 'grep jessie-backports /etc/apt/sources.list'
end.run_action(:run)

logstash_install 'kitchen' do
  version '6.5.0'
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

include_recipe 'rsyslog::client'
