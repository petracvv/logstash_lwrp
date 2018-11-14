include_recipe 'elasticsearch'
es_conf = resources('elasticsearch_configure[elasticsearch]')
es_conf.allocated_memory '128m'
es_svc = resources('elasticsearch_service[elasticsearch]')
es_svc.service_actions [:enable, :start]

logstash_install 'kitchen' do
  action :install
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

logstash_service 'kitchen' do
  xms '256M'
  xmx '256M'
  action [:start, :enable]
end

include_recipe 'rsyslog::client'
