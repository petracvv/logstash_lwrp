#
# Cookbook:: logstash_lwrp
# Resource:: service
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
resource_name :logstash_service
provides :logstash_service

property :instance, String, name_property: true
property :service_name, String, default: lazy { |r| "logstash_#{r.instance}" }
property :systemd_unit_content, String
property :description, String, default: 'logstash'
property :javacmd, String, default: '/usr/bin/java'
property :ls_settings_dir, String, default: lazy { |r| "/opt/logstash_#{r.instance}/config" }
property :ls_opts, Array, default: lazy { |r| ["--path.settings #{r.ls_settings_dir}"] }
property :ls_pidfile, String, default: lazy { |r| "/var/run/#{r.service_name}.pid" }
property :ls_gc_log_file, String, default: lazy { |r| "/opt/logstash_#{r.instance}/logs/#{r.service_name}_gc.log" }
property :ls_open_files, Integer, default: 16384
property :ls_nice, Integer, default: 19, callbacks: {
  'should be a valid nice value' => lambda { |n|
    n >= -20 && n <= 19
  },
}
property :ls_prestart, String
property :xms, String, default: node['memory'] ? "#{(node['memory']['total'].to_i * 0.6).floor / 1024}M" : '1G'
property :xmx, String, default: node['memory'] ? "#{(node['memory']['total'].to_i * 0.6).floor / 1024}M" : '1G'
property :gc_opts, Array, default: ['-XX:+UseConcMarkSweepGC',
                                    '-XX:CMSInitiatingOccupancyFraction=75',
                                    '-XX:+UseCMSInitiatingOccupancyOnly']
property :java_opts, Array, default: ['-Djava.awt.headless=true',
                                      '-Dfile.encoding=UTF-8',
                                      '-Djruby.compile.invokedynamic=true',
                                      '-Djruby.jit.threshold=0',
                                      '-XX:+HeapDumpOnOutOfMemoryError',
                                      '-Djava.security.egd=file:/dev/urandom']

action :start do
  create_init

  service new_resource.service_name do
    supports restart: true, status: true
    provider service_provider
    action :start
  end
end

action :stop do
  service new_resource.service_name do
    supports status: true
    provider service_provider
    action :stop
  end
end

action :restart do
  service new_resource.service_name do
    supports status: true
    provider service_provider
    action :restart
  end
end

action :enable do
  create_init

  service new_resource.service_name do
    supports status: true
    provider service_provider
    action :enable
  end
end

action_class do
  include LogstashLWRP::Helpers

  def service_provider
    available = Chef::Platform::ServiceHelpers.service_resource_providers

    # Service providers in same order of preference as the logstash generator
    if available.include?(:systemd) || property_is_set?(:systemd_unit_content)
      Chef::Provider::Service::Systemd
    elsif available.include?(:upstart)
      Chef::Provider::Service::Upstart
    elsif available.include?(:debian)
      Chef::Provider::Service::Init::Debian
    elsif available.include?(:redhat)
      Chef::Provider::Service::Init::Redhat
    else
      Chef::Log.fatal('Unsupported init system')
      raise
    end
  end

  def create_init
    template "#{new_resource.ls_settings_dir}/jvm.options" do
      source 'init/jvm.options.erb'
      owner logstash_user
      group logstash_group
      cookbook 'logstash_lwrp'
      variables(
        xms: new_resource.xms,
        xmx: new_resource.xmx,
        gc_opts: new_resource.gc_opts,
        java_opts: new_resource.java_opts
      )
      mode '0640'
      action :create
    end

    if property_is_set?(:systemd_unit_content)

      systemd_unit "#{new_resource.service_name}.service" do
        content new_resource.systemd_unit_content
        action :create
      end

    else
      template "#{new_resource.ls_settings_dir}/startup.options" do
        source 'init/startup.options.erb'
        owner logstash_user
        group logstash_group
        mode '0640'
        cookbook 'logstash_lwrp'
        variables(
          javacmd: new_resource.javacmd,
          ls_home: logstash_home,
          ls_settings_dir: new_resource.ls_settings_dir,
          ls_opts: new_resource.ls_opts,
          ls_pidfile: new_resource.ls_pidfile,
          ls_user: logstash_user,
          ls_group: logstash_group,
          ls_gc_log_file: new_resource.ls_gc_log_file,
          ls_open_files: new_resource.ls_open_files,
          ls_nice: new_resource.ls_nice,
          ls_service_name: new_resource.service_name,
          ls_service_description: new_resource.description,
          ls_prestart: new_resource.ls_prestart
        )
        action :create
        notifies :run, 'execute[Generate service file]', :immediately
        notifies :restart, "logstash_service[#{new_resource.instance}]", :delayed
      end

      execute 'Generate service file' do
        command "#{logstash_home}/bin/system-install #{new_resource.ls_settings_dir}/startup.options"
        user 'root'
        action :nothing
      end
    end
  end
end
