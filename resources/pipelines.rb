#
# Cookbook:: logstash_lwrp
# Resource:: pipelines
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
resource_name :logstash_pipelines

property :instance, String, name_property: true
property :mode, String, default: '0640'
property :pipelines, Array, default: [], required: true

action :deploy do
  lsuser = logstash_user
  lsgroup = logstash_group

  template "#{logstash_home}/config/pipelines.yml" do
    source 'config/pipelines.yml.erb'
    owner lsuser
    group lsgroup
    mode new_resource.mode
    variables(
      pipelines: new_resource.pipelines
    )
    cookbook 'logstash_lwrp'
    action :create
    notifies :run, 'execute[verify logstash config]', :immediately
    notifies :restart, "logstash_service[#{new_resource.instance}]", :immediately
  end

  execute 'verify logstash config' do
    command "#{logstash_home}/bin/logstash --path.settings #{logstash_home}/config -t"
    user lsuser
    group lsgroup
    action :nothing
  end
end

action_class do
  include LogstashLWRP::Helpers
end
