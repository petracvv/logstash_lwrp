# logstash_lwrp chef cookbook

A resource-driven [Chef](http://chef.io) cookbook for installing and running [Logstash](http://elastic.co/products/logstash) on GNU/Linux systems.

Provides resources for installing, configuring and running the [currently supported versions](https://www.elastic.co/support/eol) of the Logstash application.

**Installation of Logstash prerequisites such as Java are out-of-scope for this cookbook**

## Supported Software / Platforms

### Platforms

- Debian / Ubuntu
- RHEL / CentOS

### Chef

- Chef 13+

### Logstash

- 5.x
- 6.x

## Usage

This cookbook provides resources to manage Logstash including ones to install the application, create base configuration, setup processing pipelines and managing the service. In general, a normal deployment will need to use one of each resource to have a fully functioning Logstash install.

### Example

```ruby
logstash_install 'example' do
  action :install
end

logstash_config 'example' do
  action :create
end

logstash_pipeline 'main' do
  instance 'example'
  config_string "input { generator {} } filter { sleep { time => 1 } } output { stdout { codec => dots } }"
  pipeline_workers 1
  action :create
end

logstash_service 'example' do
  xms '256M'
  xmx '256M'
  action [:start, :enable]
end
```

More complex examples can be found in the test cookbook recipe: https://github.com/petracvv/logstash_lwrp/blob/master/test/fixtures/cookbooks/logstash_lwrp_test/recipes/default.rb

## Resources

### logstash_install

logstash_install installs an instance of the Logstash application using the official tar package found on Elastic's main site. At the moment, only one instance of Logstash per node is officially supported but it is possible to have multiple instances if they are using different Logstash versions.

#### Actions

- `:install`: Installs an instance of the logstash application
- `:upgrade`: Upgrades an instance of the logstash application

#### Properties

|property|description|default|kind_of|
|--------|-----------|-------|-------|
|instance|Name of the installation|nil|String|
|version|Logstash version to install|`'6.5.0'`|String|
|ls_user|User Logstash will run under|`'logstash'`|String|
|ls_group|Group Logstash will run under|`'logstash'`|String|
|ls_shell|Shell assigned to Logstash user|`'/sbin/nologin'`|String|
|install_path|Where to extract the logstash tarball|`'/opt/logstash_INSTANCENAME_VERSION/'`|String|
|install_mode|Permissions for install directory|`'0750'`|String|
|tarball_uri|Location of Logstash tarball|`'https://artifacts.elastic.co/downloads/logstash/logstash-VERSION.tar.gz'`|String|
|checksum_uri|Location of checksum for Logstash tarball|`'https://artifacts.elastic.co/downloads/logstash/logstash-VERSION.tar.gz.sha512'`|String|

#### Examples

Install a Logstash 6.4.3 instance named 'testing' to `/opt/logstash_testing_6_4_3/` with a symlink at `/opt/logstash_testing`

```ruby
logstash_install 'testing' do
  version '6.4.3'
  action :install
end
```

### logstash_config

Installs the base Logstash configuration into the `logstath.yml` file. **If you are using a Logstash 5.x version without multiple pipeline support, you will need to add your pipeline configuration with this resource instead of the `logstash_pipeline` resource.**

#### Actions

- `:create`: Deploys the configuration to the `logstash.yml` file of the named Logstash instance

#### Properties

|property|description|default|kind_of|
|--------|-----------|-------|-------|
|instance|Name of the installation|nil|String|
|mode|Permission mode of the `logstash.yml` file|`'0640'`|String|
|node_name|Name of the logstash node|`node['hostname']`|String|
|path_data|Location of persistent Logstash data|`'/opt/logstash_INSTANCE/data'`|String|
|path_logs|Location of Logstash log files|`'/opt/logstash_INSTANCE/logs'`|String|
|log_level|Log level of Logstash process|`'info'`|String|
|log_format|Log format of Logstash process|`'plain'`|String|
|pipeline_defaults|Default values for pipelines|nil|Hash|

#### Examples

Create a logstash configuration with a custom node name for the 'testing' instance

```ruby
logstash_config 'testing' do
  node_name 'logstash-test'
  action :create
end
```

Deploy the main pipeline for a 'testing' Logstash 5.x install. **This should only be done in Logstash 5.x installs since it does not support pipelines.yml**

```ruby
logstash_config 'testing' do
  node_name 'logstash-5-test'
  pipeline_defaults(
    'pipeline.id' => 'main',
    'path.config' => '/etc/mycustomlogstash/'
  )
  action :create
end
```

### logstash_pipeline

This resource deploys a pipeline to the `pipelines.yml` config file for Logstash versions that support it.

There are two main ways to deploy pipeline configuration in Logstash:

- Using a `config.string` where all your config is defined in one string in pipelines.yml
- Using a `path.config` where logstash looks for configuration files in the target path specified.

If supplied with a `config_string` property, `logstash_pipeline` will deploy a pipeline with the configuration in the `config.string` logstash property

If supplied with a `config_templates` property, `logstash_pipeline` will create a per-pipeline directory in the Logstash install location and deploy the logstash configuration files specified in the property. It will then set the `path.config` Logstash property to the created directory. **The specified templates are always deployed from the wrapper cookbook (i.e. where the `logstash_pipeline` resource is defined)**

#### Actions

- `:create`: Deploy a the pipelines.yml with the pipeline config specified

#### Properties

|property|description|default|kind_of|
|--------|-----------|-------|-------|
|pipeline_id|Name of the pipeline|nil|String|
|instance|Name of the installation|nil|String|
|mode|Permission mode of the pipelines.yml file|String|
|pipeline_workers|Number of threads for this pipeline|`node['cpu']['cores']`|Integer|
|config_string|Logstash pipeline configuration in one string|nil|String|
|config_templates|Array of template names to deploy as the Logstash pipeline configuration|Array|
|pipeline_settings|Other pipeline configuration options|nil|Hash|

#### Examples

Deploy a short pipeline configuration for the 'testing' Logstash install.

```ruby
logstash_pipeline 'string' do
  instance 'testing'
  pipeline_workers 1
  config_string "input { generator {} } filter { sleep { time => 1 } } output { stdout { codec => dots } }"
  action :create
end
```

Deploy a more complicated Logstash pipeline for the 'testing' Logstash instance using templates in your wrapper cookbook

```ruby
logstash_pipeline 'main' do
  instance 'testing'
  config_templates %w( input_syslog.conf.erb output_elasticsearch.conf.erb output_stdout.conf.erb)
  action :create
end
```

### logstash_service

This resource sets up the Logstash system service and sets the runtime Java options for the service. The service is generated using a provided upstream script; therefore, at this moment there is no way to edit the service file itself through this resource.

#### Actions

- `:start`: Creates the service and starts it
- `:stop`: Stops the service
- `:restart`: Restarts the service
- `:enable`: Creates the service and enables it (starts on boot)

#### Properties
|property|description|default|kind_of|
|--------|-----------|-------|-------|
|instance|Name of the Logstash installation|nil|String|
|service_name|Name of the Logstash service|`'logstash_INSTANCE'`|String|
|description|Longer description of the service|`'logstash'`|String|
|javacmd|Path to java binary|`'/usr/bin/java'`|String|
|ls_settings_dir|Directory with logstash.yml file|`'/opt/logstash_INSTANCE/config'`|String|
|ls_opts|Command line arguments to Logstash|`['--path.settings LS_SETTINGS_DIR']`|Array|
|ls_pidfile|Path to Logstash pidfile (only relevant for sysv)|`'/var/run/SERVICE_NAME.pid'`|String|
|ls_gc_log_file|Path to Logstash log file for Java GC|`'/opt/logstash_INSTANCE/logs/SERVICE_NAME_gc.log'`|String|
|ls_open_files|Open file limit for Logstash service|16384|Integer|
|ls_nice|Nice value for logstash process|19|Integer|
|ls_prestart|Command or script to run before Logstash service starts|nil|String|
|xms|Java Xms property for Logstash service|`node['memory'] ? "#{(node['memory']['total'].to_i * 0.6).floor / 1024}M" : '1G'`|String|
|xmx|Java Xmx property for Logstash service|`node['memory'] ? "#{(node['memory']['total'].to_i * 0.6).floor / 1024}M" : '1G'`|String|
|gc_opts|Java garbage collection options for Logstash service|see resource definition|Array|
|java_opts|Other Java options for Logstash resource|see resource definition|Array|

#### Examples

Install and start the Logstash service for the 'testing' instance with 256M as the memory limit

```ruby
logstash_service 'testing' do
  xms '256M'
  xmx '256M'
  action [:start, :enable]
end
```

## Acknowledgements

Thanks to:

- The [tomcat cookbook](https://github.com/chef-cookbooks/tomcat) authors for inspiration for the logstash_install resource pattern.
- The [haproxy cookbook](https://github.com/sous-chefs/haproxy) authors for great examples of the Chef accumulator pattern

## License & Authors

- Author: Mihai Petracovici (https://github.com/petracvv)
  
```
Copyright:: 2018, Mihai Petracovici

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
