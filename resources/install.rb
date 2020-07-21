#
# Cookbook:: logstash_lwrp
# Resource:: install
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

# Resource based on install resource from official tomcat cookbook.
# https://github.com/chef-cookbooks/tomcat/blob/master/resources/install.rb

resource_name :logstash_install
provides :logstash_install

property :instance, String, name_property: true
property :version,  String, default: '7.1.0', callbacks: {
  'should be in X.Y.Z format' => lambda { |v|
    v =~ /\d+.\d+.\d+/
  },
}
property :ls_user,  String, default: 'logstash'
property :ls_group, String, default: 'logstash'
property :ls_shell, String, default: '/sbin/nologin', callbacks: {
  'should be an installed shell' => lambda { |s|
    ::File.foreach('/etc/shells').grep s
  },
}
property :install_path, String, default: lazy { |r| "/opt/logstash_#{r.instance}_#{r.version.tr('.', '_')}/" }
property :install_mode, String, default: '0750'
property :tarball_uri, String, default: lazy { |r| "https://artifacts.elastic.co/downloads/logstash/logstash-#{r.version}.tar.gz" }
property :checksum_uri, String, default: lazy { |r| "https://artifacts.elastic.co/downloads/logstash/logstash-#{r.version}.tar.gz.sha512" }

action :install do
  package 'tar'

  tarball_path = "#{Chef::Config['file_cache_path']}/logstash-#{new_resource.version}.tar.gz"

  group new_resource.ls_group do
    append true
    action :create
  end

  user new_resource.ls_user do
    gid new_resource.ls_group
    shell new_resource.ls_shell
    system true
    action :create
  end

  directory 'logstash install directory' do
    path new_resource.install_path
    owner new_resource.ls_user
    group new_resource.ls_group
    mode new_resource.install_mode
    recursive true
    action :create
  end

  remote_file "logstash #{new_resource.version} tarball" do
    source new_resource.tarball_uri
    path tarball_path
    verify { |tarball| validate_checksum(tarball) }
    only_if { ::Dir.empty?(new_resource.install_path) } # Avoid redownloading entire logstash tarball every chef run
    action :create
    notifies :run, 'execute[extract logstash tarball]', :immediately
  end

  execute 'extract logstash tarball' do
    command "tar -xzf #{tarball_path} -C #{new_resource.install_path} --strip-components=1"
    creates ::File.join(new_resource.install_path, 'LICENSE.txt')
    action :nothing
  end

  execute "chown logstash installation as #{new_resource.ls_user}" do
    command "chown -R #{new_resource.ls_user}:#{new_resource.ls_group} #{new_resource.install_path}"
    action :nothing
    subscribes :run, 'execute[extract logstash tarball]', :immediately
  end

  link logstash_home do
    to new_resource.install_path
  end
end

action :upgrade do
  # If there is an existing installation
  if ::File.symlink?(logstash_home)
    oldinstall = ::File.realpath(logstash_home)
    oldversion = oldinstall[/[0-9]+_[0-9]+_[0-9]+/].tr('_', '.')

    notify_group 'stop logstash service before upgrade' do
      action :run
      notifies :stop, "logstash_service[#{new_resource.instance}]", :immediately
      not_if { oldversion.eql?(new_resource.version) }
    end

    # Needs to be in a block or else runs at compile-time
    ruby_block 'Install new version' do
      block do
        action_install
      end
      action :run
    end

    execute 'copy persistent data from old install' do
      command "cp -a #{oldinstall}/data #{logstash_home}/"
      user new_resource.ls_user
      action :run
      not_if { oldversion.eql?(new_resource.version) }
    end
  else # Otherwise just run the install action
    action_install
  end
end

action_class do
  include ::LogstashLWRP::Helpers

  # we have to do this since remote_file expects a checksum as a string
  def fetch_checksum
    uri = URI(new_resource.checksum_uri)
    request = Net::HTTP.new(uri.host, uri.port)
    request.use_ssl = true if uri.to_s.start_with?('https')
    response = request.get(uri)
    if response.code != '200'
      Chef::Log.fatal("Fetching the Logstash tarball checksum at #{uri} resulted in an error #{response.code}")
      raise
    end
    response.body.split(' ')[0]
  rescue => e
    Chef::Log.fatal("Could not fetch the checksum due to an error: #{e}")
    raise
  end

  def validate_checksum(file_to_check)
    desired = fetch_checksum
    # Logstash uses sha512 for their checksums
    actual = Digest::SHA512.hexdigest(::File.read(file_to_check))

    if desired == actual
      true
    else
      Chef::Log.fatal("The checksum of the Logstash tarball on disk (#{actual}) does not match the checksum provided from the mirror (#{desired}). Renaming to #{::File.basename(file_to_check)}.bad")
      ::File.rename(file_to_check, "#{file_to_check}.bad")
      raise
    end
  end
end
