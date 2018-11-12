name 'logstash_lwrp'
maintainer 'Mihai Petracovici'
maintainer_email 'petracvv@users.noreply.github.com'
license 'Apache-2.0'
description 'Resource-driven Logstash cookbook'
long_description 'Installs/Configures logstash_lwrp'
version '0.1.0'
chef_version '>= 13.0'

%w( ubuntu debian centos opensuse ).each do |os|
  supports os
end

issues_url 'https://github.com/petracvv/logstash_lwrp/issues'

source_url 'https://github.com/petracvv/logstash_lwrp'
