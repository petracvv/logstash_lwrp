#
# Cookbook:: logstash_lwrp
# Resource:: pipeline
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
resource_name :logstash_pipeline

property :pipeline_id, String, name_property: true
property :instance, String, required: true
property :mode, String, default: '0640'
property :pipeline_workers, [Integer, String], default: node['cpu']['cores']
property :config_string, String
property :config_templates, Array
property :pipeline_settings, Hash

action :create do
  validate_properties

  deploy_pipeline if property_is_set?(:config_templates)

  # Build option hash
  options = { 'pipeline.id' => new_resource.pipeline_id,
              'pipeline.workers' => new_resource.pipeline_workers,
            }
  options['config.string'] = new_resource.config_string if property_is_set?(:config_string)
  options['path.config'] = pipeline_home if property_is_set?(:config_templates)
  options = options.merge(new_resource.pipeline_settings) if property_is_set?(:pipeline_settings)

  # Wrap around logstash_pipelines for accumulator
  with_run_context :root do
    edit_resource(:logstash_pipelines, new_resource.instance) do
      action :nothing
      pipelines(pipelines + [options])
    end
  end

  log 'add pipeline' do
    notifies :deploy, "logstash_pipelines[#{new_resource.instance}]", :delayed
  end
end

action_class do
  include LogstashLWRP::Helpers

  def pipeline_home
    "#{logstash_home}/pipelines/#{new_resource.pipeline_id}"
  end

  # Logstash only allows one of config.path or config.string to be set
  def validate_properties
    if property_is_set?(:config_templates) && property_is_set?(:config_string)
      Chef::Log.fatal('Conflicting property values! Only one of config_string or config_templates can be set.')
      raise
    elsif !property_is_set?(:config_templates) && !property_is_set?(:config_string)
      Chef::Log.fatal('One of config_templates or config_string must be set!')
      raise
    end
  end

  def deploy_pipeline
    lsuser = logstash_user
    lsgroup = logstash_group

    %W( #{logstash_home}/pipelines #{pipeline_home} ).each do |path|
      directory path do
        owner lsuser
        group lsgroup
        mode '0550'
        action :create
      end
    end

    new_resource.config_templates.each do |config|
      template "#{pipeline_home}/#{::File.basename(config, '.erb')}" do
        source config
        owner lsuser
        group lsgroup
        mode new_resource.mode
        action :create
      end
    end
  end
end
