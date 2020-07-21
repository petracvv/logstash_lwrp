#
# Cookbook:: logstash_lwrp
# Resource:: config
#
# Copyright:: 2018, Mihai Petracovici
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
resource_name :logstash_config
provides :logstash_config

property :instance, String, name_property: true
property :mode, String, default: '0640'
property :node_name, String, default: lazy { node['hostname'] }
property :path_data, String, default: lazy { |r| "/opt/logstash_#{r.instance}/data" }
property :path_logs, String, default: lazy { |r| "/opt/logstash_#{r.instance}/logs" }
property :log_level, String, default: 'info', equal_to: %w( info fatal error warn debug trace )
property :log_format, String, default: 'plain', equal_to: %w( plain json )
property :pipeline_defaults, Hash

action :create do
  template "#{logstash_home}/config/logstash.yml" do
    source 'config/logstash.yml.erb'
    owner logstash_user
    group logstash_group
    mode new_resource.mode
    cookbook 'logstash_lwrp'
    variables(
      node_name: new_resource.node_name,
      path_data: new_resource.path_data,
      log_level: new_resource.log_level,
      log_format: new_resource.log_format,
      path_logs: new_resource.path_logs,
      pipeline_defaults: new_resource.pipeline_defaults
    )
    action :create
    notifies :restart, "logstash_service[#{new_resource.instance}]", :delayed
  end
end

action_class do
  include LogstashLWRP::Helpers
end
